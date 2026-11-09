"""Sonidos de Last Knight 3D sintetizados por código (sin licencias de terceros).

    python3 tools/sonidos.py assets/sonidos

Cada sonido es una función que devuelve muestras en [-1, 1] a 44,1 kHz. Algunos tienen varias tomas
(impacto_1, impacto_2…): Fx3D.sonido elige una al azar y cambia un poco el tono.
Son provisionales: se pueden sustituir por un paquete con el mismo nombre de archivo.
"""
import sys
import wave
from pathlib import Path

import numpy as np
from scipy.signal import butter, lfilter

SR = 44100
rng = np.random.default_rng(43)


def t_(d):
    return np.arange(int(SR * d)) / SR


def env(d, ataque=.004, caida=8.0):
    t = t_(d)
    e = np.exp(-t * caida)
    a = int(SR * ataque)
    if a > 0:
        e[:a] *= np.linspace(0, 1, a)
    return e


def ruido(d):
    return rng.uniform(-1, 1, int(SR * d))


def paso(x, tipo, f):
    b, a = butter(2, np.array(f) / (SR / 2), btype=tipo)
    return lfilter(b, a, x)


def seno(f, d, barrido=None):
    t = t_(d)
    if barrido is not None:
        f = np.linspace(f, barrido, len(t))
        return np.sin(2 * np.pi * np.cumsum(f) / SR)
    return np.sin(2 * np.pi * f * t)


def mezcla(*partes):
    n = max(len(p) for p in partes)
    out = np.zeros(n)
    for p in partes:
        out[:len(p)] += p
    return out


def norm(x, pico=.9):
    x = x - np.mean(x)
    m = np.max(np.abs(x)) or 1
    x = x / m * pico
    # sin clics al final
    k = min(len(x), int(SR * .01))
    x[-k:] *= np.linspace(1, 0, k)
    return x


# ---------- sonidos ----------
def impacto(var):
    d = .22
    golpe = paso(ruido(d), "lowpass", 1400 + var * 500) * env(d, .001, 26)
    cuerpo = seno(120 + var * 25, d, 55) * env(d, .001, 20) * .9
    chas = paso(ruido(.05), "highpass", 3000) * env(.05, .0005, 70) * .5
    return norm(mezcla(golpe, cuerpo, chas))


def critico():
    d = .45
    base = impacto(1)
    filo = mezcla(*[seno(f, d) * env(d, .001, 9) * a for f, a in [(1850, .35), (2730, .25), (4100, .15)]])
    sub = seno(90, .3, 40) * env(.3, .001, 12)
    return norm(mezcla(base * 1.2, filo, sub))


def muerte_enemigo(var):
    d = .55
    cruj = paso(ruido(d), "bandpass", [400, 2600]) * env(d, .002, 9 + var * 3)
    golpes = np.zeros(int(SR * d))
    for k in range(5):
        i = int(SR * (.02 + k * .045 + rng.uniform(0, .02)))
        g = paso(ruido(.04), "lowpass", 1800) * env(.04, .0005, 60)
        golpes[i:i + len(g)] += g[:len(golpes) - i]
    sorda = seno(70, d, 38) * env(d, .002, 7) * .9
    return norm(mezcla(cruj * .7, golpes, sorda))


def herido():
    d = .35
    golpe = paso(ruido(d), "lowpass", 900) * env(d, .001, 14)
    gru = seno(160, d, 95) * env(d, .01, 7) * .7
    gru = np.tanh(gru * 3) * .5
    return norm(mezcla(golpe, gru))


def bloqueo(var):
    d = .6
    parciales = [(620, 1), (1475, .7), (2380, .5), (3310, .35), (4790, .2)]
    metal = mezcla(*[seno(f * (1 + var * .04), d) * env(d, .0005, 6 + i * 3) * a for i, (f, a) in enumerate(parciales)])
    choque = paso(ruido(.04), "highpass", 2000) * env(.04, .0005, 80)
    return norm(mezcla(metal * .8, choque))


def oro(var):
    d = .32
    a = seno(2650 + var * 180, d) * env(d, .001, 14) + seno(3980 + var * 200, d) * env(d, .001, 18) * .5
    b = np.zeros(int(SR * d))
    off = int(SR * .06)
    tono = seno(3100 + var * 150, d - .06) * env(d - .06, .001, 16)
    b[off:off + len(tono)] = tono
    return norm(mezcla(a, b * .7), .6)


def explosion():
    d = 1.4
    retumbo = paso(ruido(d), "lowpass", 380) * env(d, .004, 3.2)
    estallido = paso(ruido(.3), "lowpass", 2500) * env(.3, .001, 14)
    sub = seno(55, d, 28) * env(d, .002, 3.5)
    return norm(np.tanh(mezcla(retumbo * 1.5, estallido, sub * 1.2) * 1.6))


def onda():
    d = 1.1
    sub = seno(80, d, 30) * env(d, .002, 4)
    soplo = paso(ruido(d), "bandpass", [150, 900]) * env(d, .03, 3.5)
    golpe = paso(ruido(.15), "lowpass", 1200) * env(.15, .001, 25)
    return norm(np.tanh(mezcla(sub * 1.4, soplo * .8, golpe) * 1.4))


def carga():
    d = .9
    t = t_(d)
    sube = seno(110, d, 420) * (t / d) ** 1.5
    zumb = paso(ruido(d), "bandpass", [300, 1600]) * (t / d) ** 2 * .5
    return norm(mezcla(sube, zumb), .7)


def invocar():
    d = 1.0
    t = t_(d)
    a = seno(220, d, 660) * np.sin(np.pi * t / d)
    b = seno(331, d, 990) * np.sin(np.pi * t / d) * .5
    aire = paso(ruido(d), "bandpass", [800, 4000]) * np.sin(np.pi * t / d) * .4
    trem = 1 + .4 * np.sin(2 * np.pi * 9 * t)
    return norm(mezcla(a * trem, b, aire), .7)


def jefe():
    d = 2.6
    t = t_(d)
    sobre = np.minimum(1, t / .25) * np.exp(-np.maximum(0, t - 1.6) * 3)
    cuerno = mezcla(*[seno(f, d) * a for f, a in [(73.4, 1), (110, .6), (146.8, .45), (220, .25), (77.8, .5)]])
    cuerno = np.tanh(cuerno * 2.2) * sobre
    tambor = np.zeros(int(SR * d))
    for k in range(3):
        i = int(SR * k * .38)
        g = seno(65, .5, 35) * env(.5, .002, 9)
        tambor[i:i + len(g)] += g
    return norm(mezcla(cuerno, tambor * .9))


def jefe_muere():
    d = 2.4
    base = explosion()
    t = t_(d)
    coro = mezcla(*[seno(f, d) * a for f, a in [(220, .5), (277.2, .4), (329.6, .4), (440, .3)]]) * np.minimum(1, t / .4) * np.exp(-t * 1.4)
    return norm(mezcla(base, coro * .7))


def elite():
    d = .9
    golpe = seno(98, d, 49) * env(d, .002, 5)
    disonante = mezcla(seno(466, d) * env(d, .01, 4) * .4, seno(493.9, d) * env(d, .01, 4) * .4)
    return norm(mezcla(golpe, disonante))


def escudo_roto():
    d = .55
    vidrio = mezcla(*[seno(f, d) * env(d, .0005, 9 + i * 4) * .3 for i, f in enumerate([2200, 3300, 4700, 6100])])
    cr = paso(ruido(d), "highpass", 2500) * env(d, .0005, 12) * .6
    return norm(mezcla(vidrio, cr))


def escalera_cerrada():
    d = .5
    zum = np.sign(seno(82, d)) * .3 + seno(164, d) * .3
    return norm(paso(zum, "lowpass", 900) * env(d, .01, 5), .6)


def botin():
    d = .8
    soplo = paso(ruido(d), "bandpass", [600, 3000]) * env(d, .005, 7) * .6
    monedas = np.zeros(int(SR * d))
    for k in range(7):
        i = int(SR * (.03 + k * .07 + rng.uniform(0, .03)))
        c = oro(k % 2) * .5
        monedas[i:i + len(c)] += c[:len(monedas) - i]
    golpe = seno(110, .3, 60) * env(.3, .002, 14)
    return norm(mezcla(soplo, monedas, golpe))


def legendario():
    d = 2.2
    t = t_(d)
    notas = [(523.3, 0), (659.3, .09), (784, .18), (1046.5, .27)]
    out = np.zeros(int(SR * d))
    for f, ini in notas:
        i = int(SR * ini)
        dd = d - ini
        n = (seno(f, dd) + seno(f * 2.01, dd) * .35 + seno(f * 3.02, dd) * .12) * env(dd, .003, 2.2)
        out[i:i + len(n)] += n
    brillo = paso(ruido(d), "highpass", 6000) * np.exp(-t * 3) * .15
    return norm(mezcla(out, brillo))


def dorado():
    d = 1.0
    out = mezcla(*[seno(f, d) * env(d, .003, 4 + i) * a for i, (f, a) in enumerate([(784, 1), (1175, .6), (1568, .3)])])
    return norm(out, .6)


def mimico():
    d = .7
    mordisco = mezcla(paso(ruido(.08), "lowpass", 2500) * env(.08, .0005, 50), seno(140, .5, 70) * env(.5, .002, 10))
    gru = np.tanh(seno(85, d, 60) * (1 + .6 * np.sin(2 * np.pi * 23 * t_(d))) * 3) * env(d, .02, 4) * .5
    return norm(mezcla(mordisco, gru))


def romper_madera(var):
    d = .45
    cruj = paso(ruido(d), "bandpass", [300 + var * 100, 2200]) * env(d, .001, 11)
    golpes = np.zeros(int(SR * d))
    for k in range(4):
        i = int(SR * (k * .03 + rng.uniform(0, .02)))
        g = seno(rng.uniform(180, 320), .12) * env(.12, .001, 30)
        golpes[i:i + len(g)] += g[:len(golpes) - i]
    return norm(mezcla(cruj, golpes * .8))


def romper_urna():
    d = .6
    trozos = np.zeros(int(SR * d))
    for k in range(9):
        i = int(SR * (k * .035 + rng.uniform(0, .03)))
        f = rng.uniform(1400, 3200)
        g = (seno(f, .1) + paso(ruido(.1), "highpass", 2500) * .6) * env(.1, .0005, 45)
        trozos[i:i + len(g)] += g[:len(trozos) - i]
    golpe = paso(ruido(.15), "lowpass", 900) * env(.15, .001, 25)
    return norm(mezcla(trozos, golpe))


def rejas():
    d = 1.3
    choque = bloqueo(0) * .8
    cadena = paso(ruido(d), "bandpass", [1500, 6000]) * (np.abs(np.sin(2 * np.pi * 14 * t_(d))) ** 4) * env(d, .01, 2.5) * .5
    golpe = seno(55, .8, 35) * env(.8, .002, 6)
    out = np.zeros(int(SR * d))
    i = int(SR * .45)
    out[i:i + len(choque)] += choque[:len(out) - i]
    return norm(mezcla(cadena, out, np.concatenate([np.zeros(i), golpe])[:len(out)]))


def reto():
    d = 2.0
    t = t_(d)
    notas = [(392, 0), (523.3, .14), (659.3, .28), (784, .42)]
    out = np.zeros(int(SR * d))
    for f, ini in notas:
        i = int(SR * ini)
        dd = d - ini
        n = np.tanh((seno(f, dd) + seno(f * 2, dd) * .3) * 1.5) * env(dd, .01, 2.5)
        out[i:i + len(n)] += n
    return norm(out)


def trampa_click():
    d = .2
    return norm(mezcla(paso(ruido(.03), "highpass", 2000) * env(.03, .0005, 90), seno(900, d) * env(d, .0005, 30) * .4), .6)


def pinchos():
    d = .4
    raspa = paso(ruido(d), "bandpass", [2500, 7000]) * env(d, .001, 14)
    metal = bloqueo(1) * .4
    return norm(mezcla(raspa, metal[:int(SR * d)]))


def fuego():
    d = 1.3
    t = t_(d)
    sobre = np.minimum(1, t / .08) * np.exp(-np.maximum(0, t - .9) * 8)
    rugido = paso(ruido(d), "lowpass", 1100) * sobre
    chisp = paso(ruido(d), "highpass", 4000) * (rng.uniform(0, 1, len(t)) > .997) * 3
    return norm(mezcla(rugido, chisp * .3))


def caida():
    # viento que pasa cada vez más deprisa y se aleja hacia abajo (el tono baja)
    d = 1.1
    t = t_(d)
    sobre = np.minimum(1, t / .12) * np.exp(-np.maximum(0, t - .55) * 4)
    viento = paso(ruido(d), "bandpass", [500, 2400]) * sobre
    silbido = seno(900, d, 260) * sobre * .18
    golpe = paso(ruido(.08), "lowpass", 400) * env(.08, .001, 40) * .8
    return norm(mezcla(golpe, viento, silbido), .7)


SONIDOS = {
    "impacto_1": lambda: impacto(0), "impacto_2": lambda: impacto(1), "impacto_3": lambda: impacto(2),
    "critico": critico,
    "muerte_enemigo_1": lambda: muerte_enemigo(0), "muerte_enemigo_2": lambda: muerte_enemigo(1),
    "herido": herido,
    "bloqueo_1": lambda: bloqueo(0), "bloqueo_2": lambda: bloqueo(1),
    "oro_1": lambda: oro(0), "oro_2": lambda: oro(1),
    "explosion": explosion, "onda": onda, "carga": carga, "invocar": invocar,
    "jefe": jefe, "jefe_muere": jefe_muere, "elite": elite,
    "escudo_roto": escudo_roto, "escalera_cerrada": escalera_cerrada,
    "botin": botin, "legendario": legendario, "dorado": dorado,
    "mimico": mimico, "romper_madera_1": lambda: romper_madera(0), "romper_madera_2": lambda: romper_madera(1),
    "romper_urna": romper_urna, "rejas": rejas, "reto": reto, "trampa_click": trampa_click,
    "pinchos": pinchos, "fuego": fuego, "caida": caida,
}


def guardar(ruta, x):
    datos = (np.clip(x, -1, 1) * 32767).astype("<i2").tobytes()
    with wave.open(str(ruta), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(datos)


if __name__ == "__main__":
    salida = Path(sys.argv[1] if len(sys.argv) > 1 else "assets/sonidos")
    salida.mkdir(parents=True, exist_ok=True)
    for nombre, f in SONIDOS.items():
        guardar(salida / f"{nombre}.wav", f())
        print(nombre)
