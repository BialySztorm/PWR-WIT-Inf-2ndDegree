from zipfile import ZipFile
z=ZipFile('deploy/frontend-src.zip')
roots=set(p.filename.split('/')[0] for p in z.infolist() if p.filename)
print('roots:',sorted(list(roots)))
print('has Dockerfile at root?', 'Dockerfile' in roots)
print('has dist at root?', 'dist' in roots)
print('sample index in zip exists?', any(p.filename=='index.html' or p.filename=='dist/index.html' for p in z.infolist()))
# print first 20 entries
print('\nfirst 20 entries:')
for p in z.infolist()[:20]:
    print(p.filename, p.file_size)

