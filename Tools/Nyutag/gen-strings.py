#!/usr/bin/env python3
"""Нютаг: таблица Nyutag.strings для en/ru/bxr.

Источники:
  1. Свои ключи nyutag_* из Android-форка (strings_nyutag.xml в values / values-ru / values-b+bxr).
  2. Свои ключи только для iOS и ручные замены: Tools/Nyutag/strings.tsv (key, en, ru, bxr).
  3. Русские термины: «комната» -> «группа», «пространство» -> «сообщество» (род совпадает, падежи сохраняются).
  4. Бурятский черновик строк Element из Android (translations.xml в values-b+bxr), по тем же ключам Localazy.
Таблица Nyutag проверяется в L10n.tr раньше Localizable, поэтому файлы Localazy не трогаем.
"""
import csv, glob, os, plistlib, re, sys
import xml.etree.ElementTree as ET

IOS = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ANDROID = os.path.expanduser(os.environ.get("NYUTAG_ANDROID", "~/AndroidStudioProjects/NyutagX"))
LOC = os.path.join(IOS, "ElementX/Resources/Localizations")

def android_strings(pattern):
    out = {}
    for path in sorted(glob.glob(os.path.join(ANDROID, pattern), recursive=True)):
        if "/build/" in path:
            continue
        for el in ET.parse(path).getroot().findall("string"):
            if len(el) or el.get("translatable") == "false":
                continue
            out[el.get("name")] = android_to_ios(el.text or "")
    return out

def android_to_ios(text):
    text = text.strip()
    if len(text) >= 2 and text[0] == '"' and text[-1] == '"':
        text = text[1:-1]
    text = text.replace("\\'", "'").replace('\\"', '"').replace("\\@", "@").replace("\\?", "?")
    text = re.sub(r"%(\d+\$)?s", lambda m: "%" + (m.group(1) or "") + "@", text)
    return text

def escape(value):
    return value.replace("\\", "\\\\").replace('"', '\\"').replace("\\\\n", "\\n")

def parse_strings(path):
    out = {}
    pattern = re.compile(r'^"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)";\s*$')
    for line in open(path, encoding="utf-8"):
        m = pattern.match(line.strip())
        if m:
            out[m.group(1)] = m.group(2).encode("utf-8").decode("unicode_escape").encode("latin-1").decode("utf-8")
    return out

FORMS = [  # оба слова женского рода (1-е склонение) / среднего рода (2-е склонение)
    ("комнатами", "группами"), ("комнатах", "группах"), ("комнатам", "группам"), ("комнатой", "группой"),
    ("комнату", "группу"), ("комнаты", "группы"), ("комнате", "группе"), ("комната", "группа"), ("комнат", "групп"),
    ("пространствами", "сообществами"), ("пространствах", "сообществах"), ("пространствам", "сообществам"),
    ("пространством", "сообществом"), ("пространству", "сообществу"), ("пространстве", "сообществе"),
    ("пространства", "сообщества"), ("пространство", "сообщество"), ("пространств", "сообществ"),
]

def ru_terms(value):
    for old, new in FORMS:
        value = value.replace(old, new).replace(old.capitalize(), new.capitalize())
    return value

# Английские термины так же: room -> group, space -> community (только целые слова, «subspaces» не трогаем).
EN_FORMS = [("Rooms", "Groups"), ("rooms", "groups"), ("Room", "Group"), ("room", "group"),
            ("Spaces", "Communities"), ("spaces", "communities"), ("Space", "Community"), ("space", "community")]

def en_terms(value):
    for old, new in EN_FORMS:
        value = re.sub(rf"\b{old}\b", new, value)
    return value

EN_PLURAL_FIXES = {
    "screen_room_timeline_state_changes": {"one": "%1$d change in chat", "other": "%1$d changes in chat"},
}

# Ошибки склонения в русском переводе Element (few = «2–4»): правим в своей таблице, Localizable не трогаем.
RU_PLURAL_FIXES = {
    "common_member_count": {"few": "%1$d участника"},
    "common_rooms": {"one": "%1$d комната", "few": "%1$d комнаты", "many": "%1$d комнат"},
    "screen_leave_space_submit": {"few": "Покинуть %1$d комнаты и пространство"},
    # Свёрнутые служебные события бывают и в личных чатах: «в чате», а не «в группе».
    "screen_room_timeline_state_changes": {"one": "%1$d изменение в чате", "few": "%1$d изменения в чате",
                                           "many": "%1$d изменений в чате", "other": "%1$d изменения в чате"},
}

def main():
    tables = {"en": {}, "ru": {}, "bxr": {}}
    # 4. Бурятский черновик строк Element (самый низкий приоритет — перекрывается своими ключами ниже).
    tables["bxr"].update(android_strings("**/src/main/res/values-b+bxr/translations.xml"))
    # 3. Русские термины.
    ru = parse_strings(os.path.join(LOC, "ru.lproj/Localizable.strings"))
    for key, value in ru.items():
        replaced = ru_terms(value)
        if replaced != value:
            tables["ru"][key] = replaced
    # 3а. Английские термины.
    for key, value in parse_strings(os.path.join(LOC, "en.lproj/Localizable.strings")).items():
        replaced = en_terms(value)
        if replaced != value:
            tables["en"][key] = replaced
    # 1. Свои ключи из Android.
    tables["en"].update(android_strings("**/src/main/res/values/strings_nyutag.xml"))
    tables["ru"].update(android_strings("**/src/main/res/values-ru/strings_nyutag.xml"))
    tables["bxr"].update(android_strings("**/src/main/res/values-b+bxr/strings_nyutag.xml"))
    # 2. iOS и ручные замены.
    tsv = os.path.join(IOS, "Tools/Nyutag/strings.tsv")
    if os.path.exists(tsv):
        with open(tsv, encoding="utf-8") as f:
            for row in csv.DictReader(f, delimiter="\t"):
                for lang in tables:
                    if row.get(lang):
                        tables[lang][row["key"]] = row[lang]
    # Множественные формы с терминами (Localizable.stringsdict -> Nyutag.stringsdict).
    for lang, terms, plural_fixes in (("ru", ru_terms, RU_PLURAL_FIXES), ("en", en_terms, EN_PLURAL_FIXES)):
        with open(os.path.join(LOC, f"{lang}.lproj/Localizable.stringsdict"), "rb") as f:
            plurals = plistlib.load(f)
        changed = {}
        for key, entry in plurals.items():
            fixes = plural_fixes.get(key, {})
            for variable in entry.values():
                if isinstance(variable, dict):
                    variable.update(fixes)
            dumped = plistlib.dumps(entry).decode("utf-8")
            replaced = terms(dumped)
            if replaced != dumped or fixes:
                changed[key] = plistlib.loads(replaced.encode("utf-8"))
        with open(os.path.join(LOC, f"{lang}.lproj/Nyutag.stringsdict"), "wb") as f:
            plistlib.dump(changed, f, sort_keys=True)
        print(f"{lang} plurals: {len(changed)}")
    for lang, table in tables.items():
        os.makedirs(os.path.join(LOC, f"{lang}.lproj"), exist_ok=True)
        with open(os.path.join(LOC, f"{lang}.lproj/Nyutag.strings"), "w", encoding="utf-8") as f:
            f.write("// Сгенерировано Tools/Nyutag/gen-strings.py — не править руками.\n\n")
            for key in sorted(table):
                f.write(f'"{escape(key)}" = "{escape(table[key])}";\n')
        print(f"{lang}: {len(table)} строк")

# --- Android: те же термины и ручные замены поверх Localazy, в оверлее модуля app (он перекрывает библиотеки).

ANDROID_OUT = "app/src/main/res/{qualifier}/strings_nyutag_generated.xml"
ANDROID_QUALIFIERS = {"en": "values", "ru": "values-ru", "bxr": "values-b+bxr"}

def android_names(pattern, tag=None):
    names = set()
    for path in glob.glob(os.path.join(ANDROID, pattern), recursive=True):
        if "/build/" in path:
            continue
        for el in ET.parse(path).getroot():
            if tag is None or el.tag == tag:
                names.add(el.get("name"))
    return names

def ios_to_android(text):
    text = re.sub(r"%(\d+\$)?@", lambda m: "%" + (m.group(1) or "") + "s", text)
    text = text.replace("\\", "\\\\").replace("'", "\\'").replace('"', '\\"')
    if text[:1] in ("@", "?"):
        text = "\\" + text
    return text

def write_android(lang, elements):
    path = os.path.join(ANDROID, ANDROID_OUT.format(qualifier=ANDROID_QUALIFIERS[lang]))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    root = ET.Element("resources")
    for el in sorted(elements, key=lambda e: e.get("name")):
        root.append(el)
    ET.indent(root, space="    ")
    body = ET.tostring(root, encoding="unicode")
    with open(path, "w", encoding="utf-8") as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n')
        f.write("<!-- Сгенерировано NyutagX-iOS/Tools/Nyutag/gen-strings.py — не править руками. -->\n")
        f.write(body + "\n")
    print(f"android {lang}: {len(elements)}")

def android():
    known = android_names("**/src/main/res/values/localazy.xml") | android_names("**/src/main/res/values/temporary.xml")
    tsv = {lang: {} for lang in ANDROID_QUALIFIERS}
    with open(os.path.join(IOS, "Tools/Nyutag/strings.tsv"), encoding="utf-8") as f:
        for row in csv.DictReader(f, delimiter="\t"):
            for lang in tsv:
                if row.get(lang) and row["key"] in known:
                    tsv[lang][row["key"]] = row[lang]
    for lang, qualifier in ANDROID_QUALIFIERS.items():
        # Ручные переопределения модуля app важнее, и дублей ресурсов быть не должно.
        manual = android_names(f"app/src/main/res/{qualifier}/strings_nyutag_overrides.xml")
        elements = {}
        if lang in ("ru", "en"):
            source, terms, plural_fixes = {"ru": ("values-ru/translations.xml", ru_terms, RU_PLURAL_FIXES),
                                           "en": ("values/localazy.xml", en_terms, EN_PLURAL_FIXES)}[lang]
            for path in sorted(glob.glob(os.path.join(ANDROID, "**/src/main/res/" + source), recursive=True)):
                if "/build/" in path:
                    continue
                for el in ET.parse(path).getroot():
                    name = el.get("name")
                    if name in manual:
                        continue
                    texts = [el] if el.tag == "string" else list(el) if el.tag == "plurals" else []
                    if any(len(t) for t in texts):
                        continue
                    fixes = plural_fixes.get(name, {}) if el.tag == "plurals" else {}
                    changed = bool(fixes)
                    for t in texts:
                        if t.get("quantity") in fixes:
                            t.text = '"' + fixes[t.get("quantity")] + '"'
                        new = terms(t.text or "")
                        changed |= new != (t.text or "")
                        t.text = new
                    if changed:
                        el.tail = None
                        elements[name] = el
        for name, value in tsv[lang].items():
            if name in manual:
                continue
            el = ET.Element("string", name=name)
            el.text = ios_to_android(value)
            elements[name] = el
        write_android(lang, list(elements.values()))

if __name__ == "__main__":
    main()
    if os.path.isdir(ANDROID):
        android()
