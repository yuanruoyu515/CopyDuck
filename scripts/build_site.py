"""Generate the three static introduction pages and READMEs from one content file."""
from pathlib import Path
from html import escape
import json

ROOT = Path(__file__).resolve().parents[1]
config = json.loads((ROOT / "website/content.json").read_text())
repo, homepage = config["repository"], config["homepage"]
current_version, versions = config["version"], config["releases"]
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
    releases = "".join(f'''<article class="release{' current' if version == current_version else ''}">
      <header><h3>{version}</h3><span class="badge">{text['recommended'] if version == current_version else text['legacy']}</span></header>
      <a class="button{' primary' if version == current_version else ''}" href="{download(version, 'dmg')}">DMG <span aria-hidden="true">↓</span></a>
      <div class="release-links"><a href="{download(version, 'app.zip')}">{text['appZip']}</a><a href="{repo}/releases/tag/v{version}">{text['releaseNotes']}</a></div>
    </article>''' for version in versions)
    html = f'''<!DOCTYPE html>
<html lang="{language}">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>{text['name']} · {text['tagline']}</title><meta name="description" content="{escape(text['description'], quote=True)}">
<meta name="theme-color" content="#ffffff"><meta property="og:title" content="{text['name']}"><meta property="og:description" content="{escape(text['description'], quote=True)}"><meta property="og:image" content="{homepage}assets/duck.png">
<link rel="canonical" href="{homepage}{paths[language]}">{alternates}<link rel="icon" href="{prefix}assets/favicon.png"><link rel="stylesheet" href="{prefix}style.css"></head>
<body><a class="skip" href="#main">{text['skip']}</a>
<header><div class="top wrap"><a class="brand" href="{prefix}{paths[language]}"><img src="{prefix}assets/favicon.png" alt="" width="42" height="42">{text['name']}</a><nav class="language" aria-label="{text['language']}">{nav}</nav></div></header>
<main id="main" class="wrap"><aside class="compatibility-warning" role="note"><strong>⚠️ {escape(text['compatibilityWarningTitle'])}</strong><p>{escape(text['compatibilityWarning'])}</p></aside><section class="hero"><div><p class="eyebrow">{text['eyebrow']}</p><h1>{text['heroTitle'][0]}<br>{text['heroTitle'][1]}</h1><p class="lead">{escape(text['pain'])}</p><p class="lead">{text['description']}</p><div class="actions"><a class="button primary" href="{download(current_version, 'dmg')}">{text['download']} <span aria-hidden="true">↓</span></a><a class="button" href="{repo}">{text['source']} <span aria-hidden="true">↗</span></a></div><p class="compatibility">{text['compatibility']}</p></div>
<div class="duck-stage"><div class="duck-card"><img src="{prefix}assets/duck.png" alt="" width="512" height="512" fetchpriority="high"></div><div class="shortcut"><span>{text['example']}</span><div aria-label="Control Option V"><kbd>⌃</kbd> <kbd>⌥</kbd> <kbd>V</kbd></div></div><p class="example-text">{text['exampleCaption']}</p></div></section>
<section class="section"><div class="intro"><h2>{text['originTitle']}</h2><p>{escape(text['origin'])}</p></div></section>\n<section class="section"><div class="intro"><h2>{text['howTitle']}</h2><p>{text['howBody']}</p></div><ol class="flow">{flow}</ol><div class="features">{features}</div></section>
<section class="section screenshots"><h2>{text['screenshotsTitle']}</h2><p class="intro">{text['screenshotsNote']}</p><div class="screenshot-grid">{screenshots}</div></section>
<section class="section install"><div><h2>{text['installTitle']}</h2><p>{text['compatibility']}</p></div><div><ol>{install}</ol><p class="install-note">{text['installNote']}</p></div></section>
<section class="section" id="downloads"><h2>{text['downloadsTitle']}</h2><p class="intro">{text['changes']}</p><div class="releases">{releases}</div></section>
<section class="section faq"><h2>{text['faqTitle']}</h2>{faq}</section></main>
<footer class="foot wrap"><p>{text['footer']}</p><a href="{repo}">GitHub · CopyDuck <span aria-hidden="true">↗</span></a></footer></body></html>
'''
    destination = ROOT / 'docs' / paths[language]
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(html)
    languages = ' · '.join(f'**{labels[lang]}**' if lang == language else f'[{labels[lang]}]({file})' for lang, file in readmes.items())
    def icon(name):
        return f'<img src="assets/readme/icons/{name}.svg" width="20" height="20" align="top">'
    feature_lines = '\n'.join(f'- **{title}**：{body}' if language != 'en' else f'- **{title}**: {body}' for title, body in text['features'])
    quick_lines = '\n'.join(f'{index}. **{title}**　{body}' for index, (title, body) in enumerate(text['steps'], 1))
    install_lines = '\n'.join(f'{index}. {item}' for index, item in enumerate(text['installSteps'], 1))
    older = [version for version in versions if version != current_version]
    rows = '\n'.join(f"| {version} | [DMG]({download(version, 'dmg')}) · [{text['appZip']}]({download(version, 'app.zip')}) | [{text['releaseNotes']}]({repo}/releases/tag/v{version}) |" for version in older)
    requirement_rows = '\n'.join(f'| {label} | {value} |' for label, value in text['requirements'])
    faq_lines = '\n\n'.join(f'**{question}**\n{answer}' for question, answer in text['faq'][:3])
    version_lines = '\n'.join(f'- **{version}**{"：" if language != "en" else ": "}{note}' for version, note in text['versionNotes'])
    shots = list(zip(config['screenshots'], text['screenshotTitles'], text['screenshotCaptions']))
    shot_cells = ''.join(f'''
    <td width="{width}%" valign="top">
      <img src="docs/assets/{shot['file']}" alt="{escape(title, quote=True)}">
      <p><b>{escape(title)}</b><br><sub>{escape(caption)}</sub></p>
    </td>''' for (shot, title, caption), width in zip(shots, (34, 40, 26)))
    markdown = f'''<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/readme/banner-{language}-dark.png">
  <img alt="{escape(text['readmeBannerAlt'], quote=True)}" src="assets/readme/banner-{language}-light.png">
</picture>

<p>
  <a href="{repo}/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/yuanruoyu515/CopyDuck?label=release&color=F2A33A"></a>
  <img alt="macOS 14+" src="https://img.shields.io/badge/macOS-14%2B-18181B?logo=apple&logoColor=white">
  <img alt="Apple Silicon" src="https://img.shields.io/badge/Apple_Silicon-arm64-18181B">
  <img alt="Swift, system frameworks only" src="https://img.shields.io/badge/Swift-system_frameworks_only-F2A33A?logo=swift&logoColor=white">
  <a href="https://www.threads.com/@realtimyry"><img alt="Threads @realtimyry" src="https://img.shields.io/badge/Threads-@realtimyry-18181B?logo=threads&logoColor=white"></a>
</p>

{languages} · [{text['homeLink']}]({homepage}{paths[language]}) · [{text['allReleases']}]({repo}/releases)

{text['pain']}

{text['description']}

**{text['originTitle']}**　{text['origin']}

> [!WARNING]
> **{text['compatibilityWarningTitle']}**
> {text['compatibilityWarning']}

## {icon('cursor-click')} {text['readmeFeatures']}

{feature_lines}

### {text['readmeQuick']}

{quick_lines}

<table>
  <tr>{shot_cells}
  </tr>
</table>

<sub>{text['screenshotsNote']}</sub>

## {icon('download-simple')} {text['readmeDownload']}

{text['compatibility']}

**[{text['readmeLatest']} · {current_version} DMG]({download(current_version, 'dmg')})** · [{text['appZip']}]({download(current_version, 'app.zip')}) · [{text['releaseNotes']}]({repo}/releases/tag/v{current_version})

{install_lines}

{text['installNote']}

{text["defaultShortcut"]}: <kbd>⌃</kbd> <kbd>⌥</kbd> <kbd>V</kbd> (Control + Option + V).

<details>
<summary>{text['readmeOlder']}</summary>

| {text["tableLabels"][0]} | {text["tableLabels"][1]} | {text["tableLabels"][2]} |
| --- | --- | --- |
{rows}

</details>

## {icon('puzzle-piece')} {text['readmeRequirements']}

| | |
| --- | --- |
{requirement_rows}

## {icon('tree-structure')} {text['readmeImplementation']}

{text['howBody']}

```text
NSPasteboard → TISSelectInputSource → IMKTextInput.insertText → restore previous input source
```

## {icon('warning-circle')} {text['readmeLimits']}

{faq_lines}

## {icon('trash')} {text['readmeUninstall']}

{text['faq'][3][1]}

## {text['readmeVersions']}

{version_lines}

{text['guideBody']} [{text['developerGuide']}](DEVELOPMENT.md).

## {text['readmeBuild']}

{text['buildBody']}

```sh
zsh build.sh
```

{text['buildOutput']}

{text['testBody']}

```sh
zsh scripts/test_typing.sh
zsh scripts/test_icons.sh
```

{text['packBody']}

```sh
zsh scripts/package.sh
```

## {text['readmeCredits']}

{text['credits']}

{text['madeBy']}
'''
    (ROOT / readmes[language]).write_text(markdown)

(ROOT / 'docs/style.css').write_text((ROOT / 'website/style.css').read_text())
(ROOT / 'docs/.nojekyll').touch()
print('Generated three introduction pages and three READMEs')

