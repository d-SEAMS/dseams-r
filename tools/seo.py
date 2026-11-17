#!/usr/bin/env python3
"""Add and validate SEO metadata in the generated pkgdown site."""

from __future__ import annotations

import argparse
import html
from html.parser import HTMLParser
import json
from pathlib import Path
import re
import sys
from urllib.parse import urljoin
import xml.etree.ElementTree as ET

BASE_URL = "https://r.dseams.info/"
SITE_TITLE = "dseams for R | Molecular Simulation Structure Analysis"
SITE_DESCRIPTION = (
    "R package for classifying ice, cages, rings, and bond-orientational "
    "order in molecular dynamics trajectories with the d-SEAMS engine."
)
REPOSITORY = "https://github.com/d-SEAMS/dseams-r"
DOI_URL = "https://doi.org/10.1021/acs.jcim.0c00031"
IMAGE_URL = "https://dseams.info/images/og-card.png"


def canonical_url(root: Path, page: Path) -> str:
    relative = page.relative_to(root).as_posix()
    if relative == "index.html":
        relative = ""
    elif relative.endswith("/index.html"):
        relative = relative[: -len("index.html")]
    return urljoin(BASE_URL, relative)


def attributes(tag: str) -> dict[str, str]:
    return {
        name.lower(): html.unescape(value)
        for name, _, value in re.findall(
            r"""([:\w-]+)\s*=\s*(["'])(.*?)\2""", tag, flags=re.DOTALL
        )
    }


def strip_existing_metadata(document: str) -> str:
    def keep_meta(match: re.Match[str]) -> str:
        attrs = attributes(match.group(0))
        name = attrs.get("name", "").lower()
        prop = attrs.get("property", "").lower()
        if name in {"description", "twitter:card", "twitter:title", "twitter:description"}:
            return ""
        if prop.startswith("og:"):
            return ""
        return match.group(0)

    def keep_link(match: re.Match[str]) -> str:
        rel = attributes(match.group(0)).get("rel", "").lower().split()
        return "" if "canonical" in rel else match.group(0)

    document = re.sub(r"<meta\b[^>]*>", keep_meta, document, flags=re.IGNORECASE)
    return re.sub(r"<link\b[^>]*>", keep_link, document, flags=re.IGNORECASE)


def page_title(document: str, page: Path, root: Path) -> str:
    match = re.search(r"<title\b[^>]*>(.*?)</title>", document, re.IGNORECASE | re.DOTALL)
    if not match:
        raise ValueError(f"{page.relative_to(root)} has no title element")
    title = re.sub(r"<[^>]+>", "", html.unescape(match.group(1))).strip()
    suffix = f" | {SITE_TITLE}"
    if title.endswith(suffix):
        title = title[: -len(suffix)]
    return SITE_TITLE if page == root / "index.html" else f"{title}{suffix}"


def structured_data(canonical: str, title: str, description: str) -> dict[str, object]:
    citation = {"@type": "ScholarlyArticle", "@id": DOI_URL}
    common = {
        "name": title,
        "description": description,
        "url": canonical,
        "codeRepository": REPOSITORY,
        "license": "https://spdx.org/licenses/MIT.html",
        "citation": citation,
    }
    return {
        "@context": "https://schema.org",
        "@graph": [
            {
                "@type": "SoftwareApplication",
                **common,
                "applicationCategory": "ScientificApplication",
                "operatingSystem": "Linux, macOS, Windows",
            },
            {
                "@type": "SoftwareSourceCode",
                **common,
                "programmingLanguage": ["R", "C++"],
                "runtimePlatform": "R",
            },
        ],
    }


def enhance(root: Path) -> None:
    pages = sorted(root.rglob("*.html"))
    if not pages:
        raise ValueError(f"no HTML pages found under {root}")

    urls: list[str] = []
    for page in pages:
        document = page.read_text(encoding="utf-8")
        title = page_title(document, page, root)
        canonical = canonical_url(root, page)
        short_title = title.removesuffix(f" | {SITE_TITLE}")
        description = (
            SITE_DESCRIPTION
            if page == root / "index.html"
            else f"{short_title}. {SITE_DESCRIPTION}"
        )
        document = strip_existing_metadata(document)
        escaped_title = html.escape(title, quote=True)
        escaped_description = html.escape(description, quote=True)
        escaped_url = html.escape(canonical, quote=True)
        metadata = f"""
<meta name="description" content="{escaped_description}">
<link rel="canonical" href="{escaped_url}">
<meta property="og:type" content="website">
<meta property="og:site_name" content="{html.escape(SITE_TITLE, quote=True)}">
<meta property="og:title" content="{escaped_title}">
<meta property="og:description" content="{escaped_description}">
<meta property="og:url" content="{escaped_url}">
<meta name="twitter:card" content="summary">
<meta name="twitter:title" content="{escaped_title}">
<meta name="twitter:description" content="{escaped_description}">
<script type="application/ld+json">{json.dumps(structured_data(canonical, title, description), separators=(",", ":"))}</script>
"""
        document, count = re.subn(
            r"(<title\b[^>]*>).*?(</title>)",
            lambda match: f"{match.group(1)}{escaped_title}{match.group(2)}{metadata}",
            document,
            count=1,
            flags=re.IGNORECASE | re.DOTALL,
        )
        if count != 1:
            raise ValueError(f"could not update title in {page.relative_to(root)}")
        page.write_text(document, encoding="utf-8")
        urls.append(canonical)

    sitemap = ET.Element(
        "urlset", xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"
    )
    for url in urls:
        entry = ET.SubElement(sitemap, "url")
        ET.SubElement(entry, "loc").text = url
    ET.ElementTree(sitemap).write(
        root / "sitemap.xml", encoding="utf-8", xml_declaration=True
    )


class MetadataParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.title = ""
        self._in_title = False
        self.meta: list[dict[str, str]] = []
        self.links: list[dict[str, str]] = []
        self.json_ld: list[object] = []
        self._in_json_ld = False
        self._json_buffer: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        values = {key.lower(): value or "" for key, value in attrs}
        if tag == "title":
            self._in_title = True
        elif tag == "meta":
            self.meta.append(values)
        elif tag == "link":
            self.links.append(values)
        elif tag == "script" and values.get("type", "").lower() == "application/ld+json":
            self._in_json_ld = True
            self._json_buffer = []

    def handle_endtag(self, tag: str) -> None:
        if tag == "title":
            self._in_title = False
        elif tag == "script" and self._in_json_ld:
            self._in_json_ld = False
            try:
                self.json_ld.append(json.loads("".join(self._json_buffer)))
            except json.JSONDecodeError:
                self.json_ld.append(None)

    def handle_data(self, data: str) -> None:
        if self._in_title:
            self.title += data
        if self._in_json_ld:
            self._json_buffer.append(data)


def validate(root: Path) -> None:
    pages = sorted(root.rglob("*.html"))
    if not pages:
        raise ValueError(f"no HTML pages found under {root}")
    expected_urls = {canonical_url(root, page) for page in pages}
    errors: list[str] = []

    for page in pages:
        relative = page.relative_to(root)
        parser = MetadataParser()
        parser.feed(page.read_text(encoding="utf-8"))
        expected = canonical_url(root, page)
        canonicals = [
            item.get("href", "")
            for item in parser.links
            if "canonical" in item.get("rel", "").lower().split()
        ]
        if not parser.title.strip():
            errors.append(f"{relative}: missing title")
        descriptions = [
            item.get("content", "")
            for item in parser.meta
            if item.get("name", "").lower() == "description"
        ]
        if len(descriptions) != 1 or not descriptions[0]:
            errors.append(f"{relative}: must have exactly one meta description")
        if canonicals != [expected]:
            errors.append(f"{relative}: must have exactly one canonical, {expected}")
        for prop in ("og:type", "og:title", "og:description", "og:url"):
            matching = [
                item.get("content", "")
                for item in parser.meta
                if item.get("property", "").lower() == prop
            ]
            if len(matching) != 1 or not matching[0]:
                errors.append(f"{relative}: must have exactly one {prop}")
        for name in ("twitter:card", "twitter:title", "twitter:description"):
            matching = [
                item.get("content", "")
                for item in parser.meta
                if item.get("name", "").lower() == name
            ]
            if len(matching) != 1 or not matching[0]:
                errors.append(f"{relative}: must have exactly one {name}")

        nodes = []
        for block in parser.json_ld:
            if isinstance(block, dict):
                graph = block.get("@graph", [])
                nodes.extend(graph if isinstance(graph, list) else [])
        for schema_type in ("SoftwareApplication", "SoftwareSourceCode"):
            matching = [
                node for node in nodes
                if isinstance(node, dict) and node.get("@type") == schema_type
            ]
            if not matching:
                errors.append(f"{relative}: missing JSON-LD {schema_type}")
            elif DOI_URL not in json.dumps(matching):
                errors.append(f"{relative}: {schema_type} does not cite {DOI_URL}")

    sitemap_path = root / "sitemap.xml"
    if not sitemap_path.exists():
        errors.append("missing sitemap.xml")
    else:
        namespace = {"sm": "http://www.sitemaps.org/schemas/sitemap/0.9"}
        actual_urls = {
            element.text or ""
            for element in ET.parse(sitemap_path).findall(".//sm:loc", namespace)
        }
        if actual_urls != expected_urls:
            errors.append("sitemap.xml does not contain exactly every generated HTML page")

    if errors:
        raise ValueError("\n".join(errors))
    print(f"Validated SEO metadata on {len(pages)} HTML pages.")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("site", type=Path)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    try:
        validate(args.site) if args.check else enhance(args.site)
    except ValueError as error:
        print(error, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
