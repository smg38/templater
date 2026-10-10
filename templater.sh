#!/usr/bin/env bash
# templater.sh
# v 3.3.3 2026-10-10
set -euo pipefail

progname=${0##*/}

usage() {
    cat >&2 <<'EOF'
Usage: VAR=value templater [-e ENVFILE] [-o OUTPUT] [-s] TEMPLATE
       VAR=value templater [-e ENVFILE] [-o OUTPUT] [-s] -

Behavior:
  If TEMPLATE is 'file.j3' and no -e is given, variables are loaded
  from 'file.env' (if it exists).
  If TEMPLATE is 'file.j3' and no -o is given, output is written to
  'file.out' (extension replaced).

Options:
  -e ENVFILE  загрузить переменные из ENVFILE (можно несколько раз)
  -o OUTPUT   записать результат в OUTPUT
  -s          strict: ошибка на неопределённую переменную без default
  -h          справка

Filters:
  default('V'), b64encode, b64decode, upper, lower, trim, quote,
  urlencode, sha256, md5, hexdump, replace('A','B'),
  substr(N), substr(N,M), indent(N)

Loops:
  {% for VAR in LIST %}
    ...{{ VAR }}...{{ OTHER }}...
  {% endfor %}
  LIST — переменная окружения; элементы разделены пробелами,
  табами или переводами каретки (один или несколько).
  Внутри тела доступны все переменные и фильтры.
EOF
    exit 1
}

strict=0; outfile=""; outfile_given=0; envfile=(); envfile_given=0; template=""

while getopts ":e:o:sh" opt; do
    case $opt in
        e) envfiles+=("$OPTARG"); envfile_given=1 ;;
        o) outfile=$OPTARG; outfile_given=1 ;;
        s) strict=1 ;;
        h) usage ;;
        \?) echo "$progname: неизвестная опция -$OPTARG" >&2; usage ;;
        :)  echo "$progname: опция -$OPTARG требует аргумент" >&2; usage ;;
    esac
done
shift $((OPTIND-1))
[[ $# -eq 1 ]] || usage
template=$1

if [[ "$template" != "-" ]]; then
    dir=$(dirname -- "$template"); base=$(basename -- "$template")
    stem=${base%.*}; [[ "$stem" == "$base" ]] && stem=$base
    if (( ! envfile_given )); then
        auto_env="$dir/$stem.env"
        [[ -f "$auto_env" ]] && envfiles+=("$auto_env")
    fi
    (( ! outfile_given )) && outfile="$dir/$stem.out"
fi

for envfile in ${envfiles[@]+"${envfiles[@]}"}; do
    [[ -f "$envfile" ]] || { echo "$progname: env-файл '$envfile' не найден" >&2; exit 1; }
    while IFS= read -r line || [[ -n "$line" ]]; do
        line=${line%$'\r'}
        [[ -z "${line//[[:space:]]/}" ]] && continue
        [[ "${line#"${line%%[![:space:]]*}"}" == \#* ]] && continue
        if [[ "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=(.*)$ ]]; then
            key=${BASH_REMATCH[1]}; val=${BASH_REMATCH[2]}
            val=${val#"${val%%[![:space:]]*}"}
            if [[ "$val" =~ ^\'(.*)\'$ ]]; then val=${BASH_REMATCH[1]}
            elif [[ "$val" =~ ^\"(.*)\"$ ]]; then
                val=${BASH_REMATCH[1]}
                val=${val//\\n/$'\n'}; val=${val//\\t/$'\t'}
                val=${val//\\\"/\"}; val=${val//\\\\/\\}
            else
                if [[ "$val" =~ ^(.*[^[:space:]])[[:space:]]+#.*$ ]]; then val=${BASH_REMATCH[1]}
                elif [[ "$val" =~ ^([^[:space:]]+)[[:space:]]+#.*$ ]]; then val=${BASH_REMATCH[1]}; fi
                val=${val%"${val##*[![:space:]]}"}
            fi
            [[ -z "${!key-}" ]] && export "$key=$val"
        else
            echo "$progname: пропущена строка в $envfile: $line" >&2
        fi
    done < "$envfile"
done

if [[ "$template" == "-" ]]; then
    tmp=$(mktemp); trap 'rm -f "$tmp"' EXIT
    cat > "$tmp"; template=$tmp
elif [[ ! -f "$template" ]]; then
    echo "$progname: файл '$template' не найден" >&2; exit 1
fi

if [[ -z "$outfile" || "$outfile" == "-" ]]; then target="/dev/stdout"; else target="$outfile"; fi

if [[ "$template" != "-" && -n "$outfile" ]]; then
    t_abs=$(readlink -f -- "$template" 2>/dev/null || echo "$template")
    o_abs=$(readlink -f -- "$outfile" 2>/dev/null || echo "$outfile")
    [[ "$t_abs" == "$o_abs" ]] && { echo "$progname: отказ: шаблон и выходной файл совпадают" >&2; exit 1; }
fi

if (( strict )); then
    mapfile -t used < <(grep -oE '\{\{[[:space:]]*[A-Za-z_][A-Za-z0-9_]*' "$template" | sed -E 's/\{\{[[:space:]]*//' | sort -u)
    missing=()
    for v in "${used[@]}"; do
        if [[ -z "${!v-}" ]]; then
            grep -qE "\{\{[[:space:]]*${v}[[:space:]]*\|.*default\(" "$template" || missing+=("$v")
        fi
    done
    (( ${#missing[@]} )) && { printf '%s: не определены переменные: %s\n' "$progname" "${missing[*]}" >&2; exit 2; }
fi

awk '
function trim(s) { sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }

function shellquote(s,   r, i, c) {
    r = ""
    for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (c == "\047") r = r "\047\\\047\047"
        else r = r c
    }
    return "\047" r "\047"
}

function run_capture(cmd,   out, line) {
    out = ""
    if ((cmd | getline line) > 0) out = line
    while ((cmd | getline line) > 0) out = out "\n" line
    close(cmd)
    return out
}

function f_default(v, arg) { if (v == "") return unquote(arg); return v }
function f_b64encode(v) { return run_capture("printf %s " shellquote(v) " | base64 | tr -d \047\n\047") }
function f_b64decode(v) { return run_capture("printf %s " shellquote(v) " | base64 -d 2>/dev/null") }
function f_upper(v) { return toupper(v) }
function f_lower(v) { return tolower(v) }
function f_trim(v)  { return trim(v) }
function f_quote(v) { return shellquote(v) }
function f_sha256(v) { return run_capture("printf %s " shellquote(v) " | (sha256sum 2>/dev/null || shasum -a 256) | cut -d\047 \047 -f1") }
function f_md5(v)    { return run_capture("printf %s " shellquote(v) " | (md5sum 2>/dev/null || md5) | cut -d\047 \047 -f1") }

function ord(c) {
    if (!ord_init) { for (i = 0; i < 256; i++) ord_chr[sprintf("%c", i)] = i; ord_init = 1 }
    return ord_chr[c]
}
function f_hexdump(v,   i, r) {
    r = ""
    for (i = 1; i <= length(v); i++) r = r sprintf("%02x", ord(substr(v, i, 1)))
    return r
}
function f_urlencode(v,   i, c, r) {
    r = ""
    for (i = 1; i <= length(v); i++) {
        c = substr(v, i, 1)
        if (c ~ /[A-Za-z0-9._~-]/) r = r c
        else r = r "%" sprintf("%02X", ord(c))
    }
    return r
}
function f_replace(v, arg,   p, a, b) {
    p = index(arg, ",")
    if (p == 0) return v
    a = unquote(substr(arg, 1, p-1))
    b = unquote(substr(arg, p+1))
    gsub(a, b, v)
    return v
}
function f_substr(v, arg,   p, a, b) {
    p = index(arg, ",")
    if (p == 0) return substr(v, unquote(arg)+0)
    a = unquote(substr(arg, 1, p-1)) + 0
    b = unquote(substr(arg, p+1)) + 0
    return substr(v, a, b)
}
function f_indent(v, arg,   n, pad, lines, i, m, r) {
    n = unquote(arg) + 0
    pad = sprintf("%*s", n, "")
    m = split(v, lines, "\n")
    r = ""
    for (i = 1; i <= m; i++) r = r (i > 1 ? "\n" : "") pad lines[i]
    return r
}
function unquote(s) {
    s = trim(s)
    if (s ~ /^\047.*\047$/)      s = substr(s, 2, length(s)-2)
    else if (s ~ /^".*"$/)       s = substr(s, 2, length(s)-2)
    gsub(/\\\047/, "\047", s)
    gsub(/\\\\/, "\\", s)
    return s
}
function apply_filter(v, f,   name, arg, p) {
    f = trim(f)
    p = index(f, "(")
    if (p > 0) {
        name = trim(substr(f, 1, p-1))
        arg  = substr(f, p+1)
        sub(/\)[[:space:]]*$/, "", arg)
    } else { name = f; arg = "" }
    if (name == "default")   return f_default(v, arg)
    if (name == "b64encode") return f_b64encode(v)
    if (name == "b64decode") return f_b64decode(v)
    if (name == "upper")     return f_upper(v)
    if (name == "lower")     return f_lower(v)
    if (name == "trim")      return f_trim(v)
    if (name == "quote")     return f_quote(v)
    if (name == "urlencode") return f_urlencode(v)
    if (name == "sha256")    return f_sha256(v)
    if (name == "md5")       return f_md5(v)
    if (name == "hexdump")   return f_hexdump(v)
    if (name == "replace")   return f_replace(v, arg)
    if (name == "substr")    return f_substr(v, arg)
    if (name == "indent")    return f_indent(v, arg)
    return v
}

function lv_set(d, name, val) { loop_name[d] = name; loop_val[d] = val }
function lv_get(name,   i) {
    for (i = depth; i >= 1; i--)
        if (loop_name[i] == name) return loop_val[i]
    return ""
}
function lv_has(name,   i) {
    for (i = depth; i >= 1; i--)
        if (loop_name[i] == name) return 1
    return 0
}

function split_list(s,   i, c, buf, n, in_word) {
    n = 0; buf = ""; in_word = 0
    for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (c == " " || c == "\t" || c == "\r") {
            if (in_word) { items[++n] = buf; buf = ""; in_word = 0 }
        } else { buf = buf c; in_word = 1 }
    }
    if (in_word) items[++n] = buf
    return n
}

function find_ph(line,   i, c, depth2, start, p, rest) {
    start = index(line, "{{")
    if (start == 0) { RSTART = 0; RLENGTH = 0; return 0 }
    rest = substr(line, start+2)
    depth2 = 1; i = 1; p = 0
    while (i <= length(rest)) {
        if (substr(rest, i, 2) == "{{") { depth2++; i += 2; continue }
        if (substr(rest, i, 2) == "}}") { depth2--; if (depth2 == 0) { p = i; break }; i += 2; continue }
        i++
    }
    if (p == 0) { RSTART = 0; RLENGTH = 0; return 0 }
    RSTART = start
    RLENGTH = (start + 2 + p + 1) - start   # от {{ до }} включительно
    return 1
}

function render(line,   out, pre, ph, post, body, name, rest, v, f, j, c, d2, inner) {
    out = ""
    while (find_ph(line)) {
        pre  = substr(line, 1, RSTART-1)
        ph   = substr(line, RSTART, RLENGTH)
        post = substr(line, RSTART+RLENGTH)
        body = ph
        sub(/^\{\{[[:space:]]*/, "", body)
        sub(/[[:space:]]*\}\}$/, "", body)

        # развернуть вложенные {{ var }} внутри имени
        while (match(body, /\{\{[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\}\}/)) {
            inner = substr(body, RSTART+2, RLENGTH-4)
            gsub(/[[:space:]]/, "", inner)
            if (lv_has(inner)) v = lv_get(inner)
            else               v = ENVIRON[inner]
            body = substr(body, 1, RSTART-1) v substr(body, RSTART+RLENGTH)
        }

        name = body
        sub(/[[:space:]]*\|.*$/, "", name)
        name = trim(name)

        if (lv_has(name)) v = lv_get(name)
        else              v = ENVIRON[name]

        rest = body
        sub(/^[^|]*/, "", rest)
        while (rest ~ /\|/) {
            sub(/^[[:space:]]*\|[[:space:]]*/, "", rest)
            d2 = 0; j = 1; f = ""
            while (j <= length(rest)) {
                c = substr(rest, j, 1)
                if (c == "(") d2++
                else if (c == ")") d2--
                if (c == "|" && d2 == 0) break
                f = f c; j++
            }
            v = apply_filter(v, trim(f))
            rest = substr(rest, j)
        }
        out = out pre v
        line = post
    }
    return out line
}

function render_block(text,   r) {
    r = render(text)
    sub(/\n$/, "", r)
    return r
}

function tag_kind_at(line,   kind, kpos, klen) {
    kind = ""; kpos = 0; klen = 0
    if (match(line, /\{%[[:space:]]*for[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]+in[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]*%\}/)) {
        kind = "for"; kpos = RSTART; klen = RLENGTH
    }
    if (match(line, /\{%[[:space:]]*endfor[[:space:]]*%\}/)) {
        if (kpos == 0 || RSTART < kpos) { kind = "endfor"; kpos = RSTART; klen = RLENGTH }
    }
    pos = kpos; len = klen
    return kind
}

function process_line(line,   out, kind, tag, forvar, listname, head, after,
                              before, list, cnt, body, acc, k, rendered,
                              p, ii, sep) {
    out = ""
    while (line != "") {
        kind = tag_kind_at(line)
        if (kind == "") {
            if (depth > 0) for_body[depth] = for_body[depth] line "\n"
            else           out = out render(line)
            break
        }

        if (kind == "for") {
            tag = substr(line, pos, len)
            gsub(/\{%[[:space:]]*for[[:space:]]+/, "", tag)
            gsub(/[[:space:]]*%\}/, "", tag)
            tag = trim(tag)
            p = 0
            for (ii = 1; ii <= length(tag) - 3; ii++) {
                if (substr(tag, ii, 4) == " in ") { p = ii; break }
            }
            if (p == 0) {
                print "templater: некорректный {% for %}: " tag > "/dev/stderr"
                exit 2
            }
            forvar   = trim(substr(tag, 1, p-1))
            listname = trim(substr(tag, p+4))

            head  = substr(line, 1, pos-1)
            after = substr(line, pos + len)

            if (head != "") {
                if (depth > 0) for_body[depth] = for_body[depth] head "\n"
                else           out = out render(head)
            }

            depth++
            for_name[depth] = forvar
            for_list[depth] = listname
            for_body[depth] = ""
            if (after != "") {
                if (after ~ /\{%[[:space:]]*endfor[[:space:]]*%\}/) {
                    line = after
                    continue
                }
                for_body[depth] = after
            }
            if (out != "") print out
            return
        }

        if (kind == "endfor") {
            if (depth == 0) {
                print "templater: {% endfor %} без {% for %}" > "/dev/stderr"
                exit 2
            }
            before = substr(line, 1, pos-1)
            after  = substr(line, pos + len)
            if (before != "") for_body[depth] = for_body[depth] before

            listname = for_list[depth]
            list = lv_has(listname) ? lv_get(listname) : ENVIRON[listname]
            cnt  = split_list(list)
            body = for_body[depth]
            forvar = for_name[depth]

            acc = ""
            sep = (body ~ /\n/) ? "\n" : ""
            for (k = 1; k <= cnt; k++) {
                lv_set(depth, forvar, items[k])
                rendered = render_block(body)
                if (k > 1) acc = acc sep
                acc = acc rendered
            }

            depth--
            if (depth > 0) for_body[depth] = for_body[depth] acc "\n"
            else           out = out acc

            line = after
            if (line == "") {
                if (out != "") print out
                return
            }
            continue
        }
    }
    if (out != "") print out
}

BEGIN { depth = 0 }
{ process_line($0) }
END {
    if (depth > 0) {
        print "templater: {% for %} без {% endfor %}" > "/dev/stderr"
        exit 2
    }
}
' "$template" > "$target"