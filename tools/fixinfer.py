import re,subprocess,os
# corrige «Cannot infer the type»: pone el tipo a «var x :=» en las líneas indicadas (bool si es una
# comparación, float si es una cuenta, sin tipo en otro caso), hasta que no queden
R=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
def tipo(expr):
    if re.search(r'(==|!=|<=|>=|<|>| or | and |^not |\bnot )',expr): return ': bool ='
    if re.search(r'[-+*/]|\bfloor|\bceil|\bminf|\bmaxf|\bsqrt|\bcos|\bsin|\batan2|\.st\.',expr): return ': float ='
    return ' ='
for it in range(12):
    out=subprocess.run([os.path.join(R,'tools','g.sh'),'import'],capture_output=True,text=True).stdout
    errs=re.findall(r'Cannot infer the type of "(\w+)".*?\n\s+at: GDScript::reload \(res://([^:]+):(\d+)\)',out)
    if not errs:
        print(out.strip()[:3000]); break
    by={}
    for name,f,ln in errs: by.setdefault(f,[]).append((name,int(ln)))
    for f,lst in by.items():
        p=os.path.join(R,f);L=open(p).read().split('\n')
        for name,ln in lst:
            m=re.search(r'var '+name+r'\s*:=(.*)',L[ln-1])
            if m: L[ln-1]=L[ln-1].replace(m.group(0),'var '+name+tipo(m.group(1))+m.group(1))
        open(p,'w').write('\n'.join(L))
    print('ronda',it,len(errs))
