# ZETX PC ARIZA TAKİP ONARIM — tek dosya derleyici
# kaynak/head.ps1 + kaynak/core.ps1 + kaynak/ui.ps1 + logo  ->  ZETX-PC-Ariza-Takip-Onarim.ps1
# Kullanım:  python derleme/build.py
import base64, os, re
kok = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
def oku(ad): return open(os.path.join(kok, 'kaynak', ad), encoding='utf-8-sig').read()
def temizle(s):  # PowerShell 5.1, BOM'suz okumada tipografik tırnakları tırnak sanabilir
    return s.replace('’', 'ʼ').replace('‘', 'ʼ').replace('“', '«').replace('”', '»')
core = oku('core.ps1')
assert not re.search(r"^'@", core, re.M), "core.ps1 içinde satır başında '@ olamaz"
logo = base64.b64encode(open(os.path.join(kok, 'derleme', 'logo128.png'), 'rb').read()).decode()
ana = oku('head.ps1') + "\n$Script:LogoB64 = '" + logo + "'\n$Script:CoreCode = @'\n" + core + "\n'@\n" + oku('ui.ps1')
ana = temizle(ana).replace('\r\n', '\n').replace('\n', '\r\n')
with open(os.path.join(kok, 'ZETX-PC-Ariza-Takip-Onarim.ps1'), 'wb') as f:
    f.write(b'\xef\xbb\xbf' + ana.encode('utf-8'))
print('Tamam:', len(ana.splitlines()), 'satır')
