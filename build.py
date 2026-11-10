import sys, json
url, key, out = sys.argv[1], sys.argv[2], sys.argv[3]
body = open('app-source.html').read()
head = ('<!doctype html><html lang="es"><head><meta charset="utf-8">'
 '<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">'
 '<meta name="theme-color" content="#0a0d10"><meta name="apple-mobile-web-app-capable" content="yes">'
 '<meta name="apple-mobile-web-app-title" content="Actas"><meta name="mobile-web-app-capable" content="yes">'
 '<style>:root{color-scheme:light;padding-top:env(safe-area-inset-top,0px);padding-bottom:env(safe-area-inset-bottom,0px)}body{margin:0}img{max-width:100%}[hidden]{display:none!important}</style>'
 '<script>window.ACTAS_SUPABASE=' + (json.dumps({"url": url, "key": key}) if url else 'null') + ';</script>'
 '<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.118.0/dist/umd/supabase.js"></script>'
 '</head><body>\n')
open(out, 'w').write(head + body + '\n</body></html>\n')
