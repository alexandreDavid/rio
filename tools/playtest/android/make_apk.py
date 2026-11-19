#!/usr/bin/env python3
"""Fabrique un APK Godot sans Java : gabarit + fichiers du projet + ligne de
commande, puis signature APK v2 (RSA PKCS#1 v1.5 / SHA-256) via openssl.
usage: make_apk.py template.apk project.zip out_unsigned.apk arg1 arg2 ...
       make_apk.py --sign in_aligned.apk out.apk key.pem cert.der"""
import sys, zipfile, struct, hashlib, subprocess, tempfile, os

def build(template, project, out, args):
    zin = zipfile.ZipFile(template)
    zout = zipfile.ZipFile(out, "w")
    for info in zin.infolist():
        n = info.filename
        if n.startswith("lib/") and not n.startswith("lib/arm64-v8a/"):
            continue
        if n.startswith("META-INF/") and n.endswith((".SF", ".RSA", ".MF")) and "/" not in n[9:]:
            continue
        data = zin.read(n)
        zi = zipfile.ZipInfo(n, date_time=(1981, 1, 1, 1, 1, 0))
        zi.compress_type = info.compress_type
        zi.external_attr = info.external_attr
        zout.writestr(zi, data)
    zp = zipfile.ZipFile(project)
    for info in zp.infolist():
        if info.is_dir():
            continue
        zi = zipfile.ZipInfo("assets/" + info.filename, date_time=(1981, 1, 1, 1, 1, 0))
        zi.compress_type = zipfile.ZIP_STORED
        zout.writestr(zi, zp.read(info.filename))
    # Fichiers ajoutés : arguments « +chemin_dans_assets=fichier_local ».
    extra = [a for a in args if a.startswith("+")]
    args = [a for a in args if not a.startswith("+")]
    for e in extra:
        dest, src = e[1:].split("=", 1)
        zi = zipfile.ZipInfo("assets/" + dest, date_time=(1981, 1, 1, 1, 1, 0))
        zi.compress_type = zipfile.ZIP_STORED
        zout.writestr(zi, open(src, "rb").read())
    # Ligne de commande Godot : int32 LE argc, puis (int32 LE longueur, octets).
    cl = struct.pack("<i", len(args))
    for a in args:
        b = a.encode("utf-8")
        cl += struct.pack("<i", len(b)) + b
    zi = zipfile.ZipInfo("assets/_cl_", date_time=(1981, 1, 1, 1, 1, 0))
    zi.compress_type = zipfile.ZIP_STORED
    zout.writestr(zi, cl)
    zout.close()

def lp(b):
    return struct.pack("<I", len(b)) + b

def digest_sections(sections):
    chunks = []
    for sec in sections:
        for i in range(0, len(sec), 1 << 20):
            c = sec[i:i + (1 << 20)]
            chunks.append(hashlib.sha256(b"\xa5" + struct.pack("<I", len(c)) + c).digest())
    return hashlib.sha256(b"\x5a" + struct.pack("<I", len(chunks)) + b"".join(chunks)).digest()

def sign(src, dst, key, cert_der):
    data = open(src, "rb").read()
    eocd = data.rfind(b"PK\x05\x06")
    assert eocd >= 0 and b"APK Sig Block 42" not in data
    cd_size, cd_off = struct.unpack("<II", data[eocd + 12:eocd + 20])
    assert cd_off + cd_size == eocd, "zip64 ou octets parasites"
    top = digest_sections([data[:cd_off], data[cd_off:eocd], data[eocd:]])
    ALG = 0x0103
    cert = open(cert_der, "rb").read()
    signed = lp(lp(struct.pack("<I", ALG) + lp(top))) + lp(lp(cert)) + lp(b"")
    with tempfile.NamedTemporaryFile(delete=False) as f:
        f.write(signed)
        tmp = f.name
    sig = subprocess.check_output(["openssl", "dgst", "-sha256", "-sign", key, tmp])
    pub = subprocess.check_output(["openssl", "x509", "-inform", "DER", "-in", cert_der, "-pubkey", "-noout"])
    pub_der = subprocess.run(["openssl", "pkey", "-pubin", "-outform", "DER"], input=pub, capture_output=True, check=True).stdout
    os.unlink(tmp)
    signer = lp(signed) + lp(lp(struct.pack("<I", ALG) + lp(sig))) + lp(pub_der)
    value = lp(lp(signer))
    pair = struct.pack("<QI", len(value) + 4, 0x7109871A) + value
    size = len(pair) + 8 + 16
    block = struct.pack("<Q", size) + pair + struct.pack("<Q", size) + b"APK Sig Block 42"
    new_eocd = bytearray(data[eocd:])
    struct.pack_into("<I", new_eocd, 16, cd_off + len(block))
    open(dst, "wb").write(data[:cd_off] + block + data[cd_off:eocd] + bytes(new_eocd))

if sys.argv[1] == "--sign":
    sign(*sys.argv[2:6])
else:
    build(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4:])
