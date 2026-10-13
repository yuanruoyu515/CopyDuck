"""Generate the three static introduction pages and READMEs from one content file."""
from pathlib import Path
from html import escape
import json

ROOT = Path(__file__).resolve().parents[1]
config = json.loads((ROOT / "website/content.json").read_text())
repo, homepage = config["repository"], config["homepage"]
paths = {"zh-Hans": "index.html", "zh-Hant": "zh-Hant/index.html", "en": "en/index.html"}
readmes = {"zh-Hans": "README.md", "zh-Hant": "README.zh-Hant.md", "en": "README.en.md"}
labels = {"zh-Hans": "简体中文", "zh-Hant": "繁體中文", "en": "English"}

def download(version, extension):
    return f"{repo}/releases/download/v{version}/CopyDuck-{version}-arm64.{extension}"

for language, text in config["languages"].items():
    prefix = "" if language == "zh-Hans" else "../"
    nav = "".join(f'<a href="{prefix}{path}" lang="{lang}" hreflang="{lang}"' + (' aria-current="page"' if lang == language else '') + f'>{labels[lang]}</a>' for lang, path in paths.items())
    alternates = "".join(f'<link rel="alternate" hreflang="{lang}" href="{homepage}{path}">' for lang, path in paths.items())
    flow = "".join(f'<li><span class="number">0{index}</span><h3>{escape(title)}</h3><p>{escape(body)}</p></li>' for index, (title, body) in enumerate(text["steps"], 1))
    features = "".join(f'<article><h3>{escape(title)}</h3><p>{escape(body)}</p></article>' for title, body in text["features"])
    install = "".join(f'<li>{escape(item)}</li>' for item in text["installSteps"])
    faq = "".join(f'<details><summary>{escape(question)}</summary><p>{escape(answer)}</p></details>' for question, answer in text["faq"])
    screenshots = "".join(f'''<figure class="screenshot"><a href="{prefix}assets/{shot['file']}"><img src="{prefix}assets/{shot['file']}" alt="{escape(title, quote=True)}" width="{shot['width']}" height="{shot['height']}" loading="lazy"></a><figcaption><h3>{escape(title)}</h3><p>{escape(caption)}</p></figcaption></figure>''' for shot, title, caption in zip(config['screenshots'], text['screenshotTitles'], text['screenshotCaptions']))
    releases = "".join(f'''<article class="release{' current' if version == '1.1' else ''}">
      <header><h3>{version}</h3><span class="badge">{text['recommended'] if version == '1.1' else text['legacy']}</span></header>
      <a class="button{' primary' if version == '1.1' else ''}" href="{download(version, 'dmg')}">DMG <span aria-hidden="true">↓</span></a>
      <div class="release-links"><a href="{download(version, 'app.zip')}">{text['appZip']}</a><a href="{repo}/releases/tag/v{version}">{text['releaseNotes']}</a></div>
    </article>''' for version in ['1.1', '1.0'])
    html = f'''<!DOCTYPE html>
<html lang="{language}">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>{text['name']} · {text['tagline']}</title><meta name="description" content="{escape(text['description'], quote=True)}">
<meta name="theme-color" content="#ffffff"><meta property="og:title" content="{text['name']}"><meta property="og:description" content="{escape(text['description'], quote=True)}"><meta property="og:image" content="{homepage}assets/duck.png">
<link rel="canonical" href="{homepage}{paths[language]}">{alternates}<link rel="icon" href="{prefix}assets/favicon.png"><link rel="stylesheet" href="{prefix}style.css"></head>
<body><a class="skip" href="#main">{text['skip']}</a>
<header><div class="top wrap"><a class="brand" href="{prefix}{paths[language]}"><img src="{prefix}assets/favicon.png" alt="" width="42" height="42">{text['name']}</a><nav class="language" aria-label="{text['language']}">{nav}</nav></div></header>
<main id="main" class="wrap"><section class="hero"><div><p class="eyebrow">{text['eyebrow']}</p><h1>{text['heroTitle'][0]}<br>{text['heroTitle'][1]}</h1><p class="lead">{text['description']}</p><div class="actions"><a class="button primary" href="{download('1.1', 'dmg')}">{text['download']} <span aria-hidden="true">↓</span></a><a class="button" href="{repo}">{text['source']} <span aria-hidden="true">↗</span></a></div><p class="compatibility">{text['compatibility']}</p></div>
<div class="duck-stage"><div class="duck-card"><img src="{prefix}assets/duck.png" alt="" width="512" height="512" fetchpriority="high"></div><div class="shortcut"><span>{text['example']}</span><div aria-label="Control Option V"><kbd>⌃</kbd> <kbd>⌥</kbd> <kbd>V</kbd></div></div><p class="example-text">{text['exampleCaption']}</p></div></section>
<section class="section"><div class="intro"><h2>{text['howTitle']}</h2><p>{text['howBody']}</p></div><ol class="flow">{flow}</ol><div class="features">{features}</div></section>
<section class="section screenshots"><h2>{text['screenshotsTitle']}</h2><p class="intro">{text['screenshotsNote']}</p><div class="screenshot-grid">{screenshots}</div></section>
<section class="section install"><div><h2>{text['installTitle']}</h2><p>{text['compatibility']}</p></div><div><ol>{install}</ol><p class="install-note">{text['installNote']}</p></div></section>
<section class="section" id="downloads"><h2>{text['downloadsTitle']}</h2><p class="intro">{text['changes']}</p><div class="releases">{releases}</div></section>
<section class="section faq"><h2>{text['faqTitle']}</h2>{faq}</section></main>
<footer class="foot wrap"><p>{text['footer']}</p><a href="{repo}">GitHub · CopyDuck <span aria-hidden="true">↗</span></a></footer></body></html>
'''
    destination = ROOT / 'docs' / paths[language]
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(html)
    languages = ' · '.join(f'[{labels[lang]}]({file})' for lang, file in readmes.items())
    feature_lines = '\n'.join(f'- **{title}**：{body}' for title, body in text['features'])
    install_lines = '\n'.join(f'{index}. {item}' for index, item in enumerate(text['installSteps'], 1))
    rows = '\n'.join(f"| {version} | [DMG]({download(version, 'dmg')}) · [{text['appZip']}]({download(version, 'app.zip')}) | [{text['releaseNotes']}]({repo}/releases/tag/v{version}) |" for version in ['1.1','1.0'])
    screenshot_markdown = '\n\n'.join(f"### {title}\n\n<img src=\"docs/assets/{shot['file']}\" alt=\"{escape(title, quote=True)}\" width=\"{560 if index < 2 else 360}\">\n\n{caption}" for index, (shot, title, caption) in enumerate(zip(config['screenshots'], text['screenshotTitles'], text['screenshotCaptions'])))
    markdown = f'''<p align="center"><img src="docs/assets/duck.png" alt="{text['name']}" width="128"></p>

# {text['name']} · CopyDuck

{languages}

**{text['tagline']}**

{text['description']}

[{text['homeLink']}]({homepage}{paths[language]}) · [{text['allReleases']}]({repo}/releases)

## {text['readmeDownload']}

{text['compatibility']}

| {text["tableLabels"][0]} | {text["tableLabels"][1]} | {text["tableLabels"][2]} |
| --- | --- | --- |
{rows}

## {text['readmeFeatures']}

{feature_lines}

## {text['screenshotsTitle']}

{text['screenshotsNote']}

{screenshot_markdown}

## {text['readmeInstall']}

{install_lines}

{text['installNote']}

{text["defaultShortcut"]}: **⌃⌥V** (Control + Option + V).

## {text['readmeImplementation']}

{text['howBody']}

`NSPasteboard → TISSelectInputSource → IMKTextInput.insertText → restore previous input source`

## {text['readmeNotes']}

{text['faq'][0][1]}

{text['faq'][1][1]}

{text['faq'][2][1]}

{text['faq'][3][1]}

## {text['readmeVersions']}

{text['changes']}

{text['guideBody']} [{text['developerGuide']}](DEVELOPMENT.md).

## {text['readmeBuild']}

{text['buildBody']}

```sh
zsh build.sh
```

{text['buildOutput']}

{text['testBody']}

```sh
zsh scripts/test_icons.sh
```

{text['packBody']}

```sh
zsh scripts/package.sh
```
'''
    (ROOT / readmes[language]).write_text(markdown)

(ROOT / 'docs/style.css').write_text((ROOT / 'website/style.css').read_text())
(ROOT / 'docs/.nojekyll').touch()
print('Generated three introduction pages and three READMEs')
