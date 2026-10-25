import base64,hashlib,json,subprocess,pathlib,shutil,copy,re,yaml,os
B=pathlib.Path('/root/fomio-search-error-backup-20261020')
assert not B.exists(), 'backup already exists; inspect before retry'
B.mkdir(mode=0o700)
def run(*a): return subprocess.check_output(a,text=True).strip()
rev=run('docker','exec','-u','discourse','app','git','-C','/var/www/discourse','rev-parse','HEAD')
assert rev=='821e9e2f9f94483a3be8d1e077cde0fd94970479'
assert not run('docker','exec','-u','discourse','app','git','-C','/var/www/discourse','status','--porcelain')
files={'lib/search.rb':'911d7c4ce60a8a016ab314e27e0755375524be6a7326cf4d6820d889a8e1efaf','config/locales/server.en.yml':'5ad37aa72e256082a14500f159c5fe1d0700c117bc8d11d3f472dfd604182198'}
for f,h in files.items():
 data=subprocess.check_output(['docker','exec','app','cat','/var/www/discourse/'+f]); assert hashlib.sha256(data).hexdigest()==h
 out=B/f; out.parent.mkdir(parents=True,exist_ok=True); out.write_bytes(data)
cfg=pathlib.Path('/var/discourse/containers/app.yml'); shutil.copy2(cfg,B/'app.yml')
patch=base64.b64decode('LS0tIGEvbGliL3NlYXJjaC5yYgorKysgYi9saWIvc2VhcmNoLnJiCkBAIC0zNjcsNiArMzY3LDcgQEAKICAgICBlbmQKIAogICAgIGZpbmRfZ3JvdXBlZF9yZXN1bHRzIGlmIEByZXN1bHRzLnBvc3RzLmJsYW5rPworICAgIHJldHVybiBAcmVzdWx0cyBpZiBAcmVzdWx0cy5lcnJvci5wcmVzZW50PwogCiAgICAgaWYgcHJlbG9hZGVkX3RvcGljX2N1c3RvbV9maWVsZHMucHJlc2VudD8gJiYgQHJlc3VsdHMucG9zdHMucHJlc2VudD8KICAgICAgIHRvcGljcyA9IEByZXN1bHRzLnBvc3RzLm1hcCgmOnRvcGljKQpAQCAtMTA4Miw5ICsxMDgzLDE2IEBACiAgICAgZW5kCiAKICAgICBAcmVzdWx0cwotICByZXNjdWUgQWN0aXZlUmVjb3JkOjpTdGF0ZW1lbnRJbnZhbGlkCi0gICAgIyBJbiB0aGUgZXZlbnQgb2YgYSBQRzpFcnJvciByZXR1cm4gbm90aGluZywgaXQgaXMgbGlrZWx5IHRoZXkgdXNlZCBhIGZvcmVpZ24gbGFuZ3VhZ2Ugd2hvc2UKLSAgICAjIGxvY2FsZSBpcyBub3Qgc3VwcG9ydGVkIGJ5IHBvc3RncmVzCisgIHJlc2N1ZSBBY3RpdmVSZWNvcmQ6OlN0YXRlbWVudEludmFsaWQgPT4gZXJyb3IKKyAgICBEaXNjb3Vyc2Uud2Fybl9leGNlcHRpb24oZXJyb3IpCisgICAgQHJlc3VsdHMgPQorICAgICAgR3JvdXBlZFNlYXJjaFJlc3VsdHMubmV3KAorICAgICAgICB0eXBlX2ZpbHRlcjogQHJlc3VsdHMudHlwZV9maWx0ZXIsCisgICAgICAgIHRlcm06IEByZXN1bHRzLnRlcm0sCisgICAgICAgIHNlYXJjaF9jb250ZXh0OiBAcmVzdWx0cy5zZWFyY2hfY29udGV4dCwKKyAgICAgICkKKyAgICBAcmVzdWx0cy5lcnJvciA9IEkxOG4udCgic2VhcmNoLnF1ZXJ5X2Vycm9yIikKKyAgICBAcmVzdWx0cwogICBlbmQKIAogICAjIElmIHdlJ3JlIHNlYXJjaGluZyBmb3IgYSBzaW5nbGUgdG9waWMKLS0tIGEvY29uZmlnL2xvY2FsZXMvc2VydmVyLmVuLnltbAorKysgYi9jb25maWcvbG9jYWxlcy9zZXJ2ZXIuZW4ueW1sCkBAIC0zMzQ5LDYgKzMzNDksNyBAQAogICAgICAgICB2YWx1ZTogIkRpc2NvdXJzZUNvbm5lY3Qgc2VjcmV0IgogCiAgIHNlYXJjaDoKKyAgICBxdWVyeV9lcnJvcjogIlNlYXJjaCBjb3VsZCBub3QgYmUgY29tcGxldGVkLiBQbGVhc2UgdHJ5IGFnYWluLiIKICAgICBleHRyZW1lX2xvYWRfZXJyb3I6ICJTaXRlIGlzIHVuZGVyIGV4dHJlbWUgbG9hZCwgc2VhcmNoIGlzIGRpc2FibGVkLCB0cnkgYWdhaW4gbGF0ZXIiCiAgICAgd2l0aGluX3Bvc3Q6ICIjJXtwb3N0X251bWJlcn0gYnkgJXt1c2VybmFtZX0iCiAgICAgdHlwZXM6Cg=='); (B/'runtime.patch').write_bytes(patch)
subprocess.run(['docker','cp',str(B/'runtime.patch'),'app:/tmp/fomio-search-error.patch'],check=True)
run('docker','exec','-u','discourse','app','git','-C','/var/www/discourse','apply','--check','/tmp/fomio-search-error.patch')
old=cfg.read_text(); parsed=yaml.safe_load(old); expected=copy.deepcopy(parsed)
command="printf %s LS0tIGEvbGliL3NlYXJjaC5yYgorKysgYi9saWIvc2VhcmNoLnJiCkBAIC0zNjcsNiArMzY3LDcgQEAKICAgICBlbmQKIAogICAgIGZpbmRfZ3JvdXBlZF9yZXN1bHRzIGlmIEByZXN1bHRzLnBvc3RzLmJsYW5rPworICAgIHJldHVybiBAcmVzdWx0cyBpZiBAcmVzdWx0cy5lcnJvci5wcmVzZW50PwogCiAgICAgaWYgcHJlbG9hZGVkX3RvcGljX2N1c3RvbV9maWVsZHMucHJlc2VudD8gJiYgQHJlc3VsdHMucG9zdHMucHJlc2VudD8KICAgICAgIHRvcGljcyA9IEByZXN1bHRzLnBvc3RzLm1hcCgmOnRvcGljKQpAQCAtMTA4Miw5ICsxMDgzLDE2IEBACiAgICAgZW5kCiAKICAgICBAcmVzdWx0cwotICByZXNjdWUgQWN0aXZlUmVjb3JkOjpTdGF0ZW1lbnRJbnZhbGlkCi0gICAgIyBJbiB0aGUgZXZlbnQgb2YgYSBQRzpFcnJvciByZXR1cm4gbm90aGluZywgaXQgaXMgbGlrZWx5IHRoZXkgdXNlZCBhIGZvcmVpZ24gbGFuZ3VhZ2Ugd2hvc2UKLSAgICAjIGxvY2FsZSBpcyBub3Qgc3VwcG9ydGVkIGJ5IHBvc3RncmVzCisgIHJlc2N1ZSBBY3RpdmVSZWNvcmQ6OlN0YXRlbWVudEludmFsaWQgPT4gZXJyb3IKKyAgICBEaXNjb3Vyc2Uud2Fybl9leGNlcHRpb24oZXJyb3IpCisgICAgQHJlc3VsdHMgPQorICAgICAgR3JvdXBlZFNlYXJjaFJlc3VsdHMubmV3KAorICAgICAgICB0eXBlX2ZpbHRlcjogQHJlc3VsdHMudHlwZV9maWx0ZXIsCisgICAgICAgIHRlcm06IEByZXN1bHRzLnRlcm0sCisgICAgICAgIHNlYXJjaF9jb250ZXh0OiBAcmVzdWx0cy5zZWFyY2hfY29udGV4dCwKKyAgICAgICkKKyAgICBAcmVzdWx0cy5lcnJvciA9IEkxOG4udCgic2VhcmNoLnF1ZXJ5X2Vycm9yIikKKyAgICBAcmVzdWx0cwogICBlbmQKIAogICAjIElmIHdlJ3JlIHNlYXJjaGluZyBmb3IgYSBzaW5nbGUgdG9waWMKLS0tIGEvY29uZmlnL2xvY2FsZXMvc2VydmVyLmVuLnltbAorKysgYi9jb25maWcvbG9jYWxlcy9zZXJ2ZXIuZW4ueW1sCkBAIC0zMzQ5LDYgKzMzNDksNyBAQAogICAgICAgICB2YWx1ZTogIkRpc2NvdXJzZUNvbm5lY3Qgc2VjcmV0IgogCiAgIHNlYXJjaDoKKyAgICBxdWVyeV9lcnJvcjogIlNlYXJjaCBjb3VsZCBub3QgYmUgY29tcGxldGVkLiBQbGVhc2UgdHJ5IGFnYWluLiIKICAgICBleHRyZW1lX2xvYWRfZXJyb3I6ICJTaXRlIGlzIHVuZGVyIGV4dHJlbWUgbG9hZCwgc2VhcmNoIGlzIGRpc2FibGVkLCB0cnkgYWdhaW4gbGF0ZXIiCiAgICAgd2l0aGluX3Bvc3Q6ICIjJXtwb3N0X251bWJlcn0gYnkgJXt1c2VybmFtZX0iCiAgICAgdHlwZXM6Cg== | base64 -d > /tmp/fomio-search-error.patch && su discourse -c 'cd /var/www/discourse && (git apply --reverse --check /tmp/fomio-search-error.patch 2>/dev/null || (git apply --check /tmp/fomio-search-error.patch && git apply /tmp/fomio-search-error.patch))'"
# Insert a separate after_code exec without rewriting secret-bearing configuration.
lines=old.splitlines(True); start=next(i for i,l in enumerate(lines) if re.match(r'^  after_code:\s*$',l)); end=start+1
while end<len(lines) and (not lines[end].strip() or lines[end].lstrip().startswith('#') or len(lines[end])-len(lines[end].lstrip())>2): end+=1
entry={'exec':{'cmd':command}}
expected['hooks']['after_code'].append(entry)
addition='    - exec:\n        cmd: '+json.dumps(command)+'\n'
new=''.join(lines[:end])+addition+''.join(lines[end:]); assert yaml.safe_load(new)==expected
cfg.write_text(new)
try:
 run('docker','exec','-u','discourse','app','git','-C','/var/www/discourse','apply','/tmp/fomio-search-error.patch')
except Exception:
 shutil.copy2(B/'app.yml',cfg); raise
result={'base_revision':rev,'runtime_patch_sha256':hashlib.sha256(patch).hexdigest(),'backup':str(B),'rebuild_hook':True,'image':run('docker','inspect','--format','{{.Image}}','app')}
result['files']=run('docker','exec','app','sha256sum',*[ '/var/www/discourse/'+f for f in files]).splitlines()
(B/'deployment.json').write_text(json.dumps(result,indent=2)); print(json.dumps(result,indent=2))
