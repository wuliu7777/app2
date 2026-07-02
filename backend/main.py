from fastapi import FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
import yt_dlp
import json
import re
import requests
import urllib.parse


app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class ExtractRequest(BaseModel):
    url_text: str


TRAILING_URL_PUNCTUATION = ".,;:!?)]}'\"，。；：！？）】》、"
BROWSER_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/126.0.0.0 Safari/537.36"
    ),
    "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
}
BILIBILI_REFERER = "https://www.bilibili.com"
DOUYIN_REFERER = "https://www.douyin.com"


def find_first_url(text: str) -> str | None:
    pattern = re.compile(r"https?://[^\s，。；：！？）】》]+")
    match = pattern.search(text)
    if not match:
        return None
    return match.group(0).strip(TRAILING_URL_PUNCTUATION)


def is_bilibili_url(url: str) -> bool:
    host = urllib.parse.urlparse(url).netloc.lower()
    return "bilibili.com" in host or host == "b23.tv"


def is_douyin_url(url: str) -> bool:
    host = urllib.parse.urlparse(url).netloc.lower()
    return host.endswith("douyin.com")


def resolve_redirect_url(url: str, http_client=requests) -> str:
    response = http_client.get(
        url,
        headers=BROWSER_HEADERS,
        allow_redirects=True,
        timeout=10,
    )
    response.raise_for_status()
    return response.url


def resolve_bilibili_url(url: str, http_client=requests) -> str:
    host = urllib.parse.urlparse(url).netloc.lower()
    if host != "b23.tv":
        return url

    return resolve_redirect_url(url, http_client=http_client)


def extract_bvid(url: str) -> str | None:
    match = re.search(r"(BV[0-9A-Za-z]+)", url)
    return match.group(1) if match else None


def build_stream_proxy_url(video_url: str, referer: str = BILIBILI_REFERER) -> str:
    query = urllib.parse.urlencode({"url": video_url, "referer": referer})
    return f"http://127.0.0.1:8000/api/stream?{query}"


def first_url_from_value(value):
    if isinstance(value, str) and value.startswith("http"):
        return value
    if isinstance(value, list):
        for item in value:
            found = first_url_from_value(item)
            if found:
                return found
    if isinstance(value, dict):
        if "url_list" in value:
            found = first_url_from_value(value["url_list"])
            if found:
                return found
        for item in value.values():
            found = first_url_from_value(item)
            if found:
                return found
    return None


def find_nested_value(data, wanted_keys):
    if isinstance(data, dict):
        for key in wanted_keys:
            if key in data:
                return data[key]
        for value in data.values():
            found = find_nested_value(value, wanted_keys)
            if found is not None:
                return found
    if isinstance(data, list):
        for item in data:
            found = find_nested_value(item, wanted_keys)
            if found is not None:
                return found
    return None


def find_douyin_video_url(data):
    for key in ("play_addr", "download_addr", "playAddr", "downloadAddr"):
        value = find_nested_value(data, {key})
        url = first_url_from_value(value)
        if url:
            return url
    return None


def find_douyin_cover_url(data):
    for key in ("cover", "origin_cover", "dynamic_cover", "videoCover"):
        value = find_nested_value(data, {key})
        url = first_url_from_value(value)
        if url:
            return url
    return ""


def find_douyin_title(data):
    value = find_nested_value(data, {"desc", "title", "caption"})
    return value if isinstance(value, str) and value.strip() else "未命名抖音视频"


def parse_json_script_by_id(webpage: str, script_id: str):
    pattern = re.compile(
        rf'<script[^>]+id=["\']{re.escape(script_id)}["\'][^>]*>(.*?)</script>',
        re.DOTALL,
    )
    match = pattern.search(webpage)
    if not match:
        return None

    raw = match.group(1).strip()
    if not raw:
        return None

    if script_id == "RENDER_DATA":
        raw = urllib.parse.unquote(raw)

    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return None


def extract_bilibili_video(target_url: str, http_client=requests):
    source_url = resolve_bilibili_url(target_url, http_client=http_client)
    bvid = extract_bvid(source_url)

    if not bvid:
        raise HTTPException(status_code=400, detail="没有识别到 B 站 BV 号")

    view_response = http_client.get(
        "https://api.bilibili.com/x/web-interface/view",
        params={"bvid": bvid},
        headers={**BROWSER_HEADERS, "Referer": BILIBILI_REFERER},
        timeout=15,
    )
    view_response.raise_for_status()
    view_payload = view_response.json()

    if view_payload.get("code") != 0:
        message = view_payload.get("message") or "B 站视频信息接口返回异常"
        raise HTTPException(status_code=400, detail=f"B站视频信息获取失败: {message}")

    view_data = view_payload.get("data") or {}
    cid = view_data.get("cid")
    if not cid:
        raise HTTPException(status_code=400, detail="B站视频信息缺少 cid")

    play_response = http_client.get(
        "https://api.bilibili.com/x/player/playurl",
        params={
            "bvid": bvid,
            "cid": cid,
            "qn": 64,
            "fnval": 0,
            "otype": "json",
            "platform": "html5",
            "high_quality": 1,
        },
        headers={**BROWSER_HEADERS, "Referer": source_url},
        timeout=15,
    )
    play_response.raise_for_status()
    play_payload = play_response.json()

    if play_payload.get("code") != 0:
        message = play_payload.get("message") or "B 站播放地址接口返回异常"
        raise HTTPException(status_code=400, detail=f"B站播放地址获取失败: {message}")

    play_data = play_payload.get("data") or {}
    durl = play_data.get("durl") or []
    video_url = durl[0].get("url") if durl and isinstance(durl[0], dict) else None

    if not video_url:
        raise HTTPException(
            status_code=400,
            detail="B站返回了 DASH 分离音视频流，当前版本暂不支持合流播放",
        )

    return {
        "title": view_data.get("title") or "未命名B站视频",
        "cover_url": view_data.get("pic") or "",
        "video_url": build_stream_proxy_url(video_url, referer=source_url),
        "source_url": source_url,
    }


def extract_with_ytdlp(target_url: str, platform_name: str = "视频"):
    ydl_opts = {
        "quiet": True,
        "no_warnings": True,
        "noplaylist": True,
        "nocheckcertificate": True,
        "format": "best[ext=mp4]/best",
        "skip_download": True,
        "http_headers": BROWSER_HEADERS,
    }

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(target_url, download=False)

        video_url = info.get("url")

        if not video_url and info.get("formats"):
            formats = info["formats"]
            usable_formats = [
                f for f in formats
                if f.get("url") and f.get("vcodec") != "none"
            ]

            if usable_formats:
                usable_formats.sort(
                    key=lambda f: f.get("height") or 0,
                    reverse=True
                )
                video_url = usable_formats[0].get("url")

        if not video_url:
            raise HTTPException(status_code=400, detail=f"{platform_name}解析成功，但没有找到可播放视频地址")

        return {
            "title": info.get("title") or "未命名视频",
            "cover_url": info.get("thumbnail") or "",
            "video_url": video_url,
            "source_url": target_url,
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"{platform_name}解析失败: {str(e)}")


def extract_douyin_video(target_url: str, http_client=requests, parser=None):
    source_url = target_url
    host = urllib.parse.urlparse(target_url).netloc.lower()
    if host == "v.douyin.com":
        source_url = resolve_redirect_url(target_url, http_client=http_client)

    parse = parser or (lambda url: extract_with_ytdlp(url, platform_name="抖音"))
    try:
        result = parse(source_url)
    except Exception as e:
        try:
            result = extract_douyin_webpage_video(source_url, http_client=http_client)
        except HTTPException as fallback_error:
            raise HTTPException(
                status_code=400,
                detail=f"抖音解析失败: yt-dlp={str(e)}; 页面兜底={fallback_error.detail}",
            )

    result["platform"] = "douyin"
    result["source_url"] = source_url
    return result


def extract_douyin_aweme_id(url: str) -> str | None:
    parsed = urllib.parse.urlparse(url)
    query = urllib.parse.parse_qs(parsed.query)
    for key in ("modal_id", "aweme_id", "item_id"):
        if query.get(key):
            return query[key][0]

    match = re.search(r"/(?:video|note)/(\d+)", parsed.path)
    return match.group(1) if match else None


def extract_douyin_webpage_video(target_url: str, http_client=requests):
    response = http_client.get(
        target_url,
        headers={**BROWSER_HEADERS, "Referer": DOUYIN_REFERER},
        timeout=15,
    )
    response.raise_for_status()
    webpage = response.text

    candidates = [
        parse_json_script_by_id(webpage, "RENDER_DATA"),
        parse_json_script_by_id(webpage, "__UNIVERSAL_DATA_FOR_REHYDRATION__"),
    ]

    data = next((item for item in candidates if item), None)
    if not data:
        raise HTTPException(status_code=400, detail="抖音页面中没有找到可解析 JSON 数据")

    video_url = find_douyin_video_url(data)
    if not video_url:
        raise HTTPException(status_code=400, detail="抖音页面 JSON 中没有找到播放地址")

    return {
        "title": find_douyin_title(data),
        "cover_url": find_douyin_cover_url(data),
        "video_url": build_stream_proxy_url(video_url, referer=target_url),
        "source_url": target_url,
        "platform": "douyin",
        "aweme_id": extract_douyin_aweme_id(target_url) or "",
    }


@app.get("/")
def root():
    return {"status": "ok", "message": "Video extractor backend is running"}


@app.post("/api/extract")
def extract_video(request: ExtractRequest):
    target_url = find_first_url(request.url_text)

    if not target_url:
        raise HTTPException(status_code=400, detail="没有找到有效链接")

    if is_bilibili_url(target_url):
        return extract_bilibili_video(target_url)

    if is_douyin_url(target_url):
        return extract_douyin_video(target_url)

    return extract_with_ytdlp(target_url)


@app.get("/api/stream")
def proxy_stream(
    url: str,
    referer: str = "",
    range_header: str | None = Header(default=None, alias="Range"),
):
    headers = {**BROWSER_HEADERS}
    if referer:
        headers["Referer"] = referer
    if range_header:
        headers["Range"] = range_header

    try:
        req = requests.get(url, headers=headers, stream=True, timeout=30)
        req.raise_for_status()

        def iterfile():
            for chunk in req.iter_content(chunk_size=1024 * 1024):
                if chunk:
                    yield chunk

        response_headers = {
            "Accept-Ranges": req.headers.get("Accept-Ranges", "bytes"),
            "Cache-Control": "no-store",
        }
        for header_name in ("Content-Length", "Content-Range", "Content-Type"):
            if req.headers.get(header_name):
                response_headers[header_name] = req.headers[header_name]

        return StreamingResponse(
            iterfile(),
            status_code=req.status_code,
            media_type=req.headers.get("Content-Type") or "video/mp4",
            headers=response_headers,
        )

    except Exception as e:
        raise HTTPException(status_code=400, detail=f"视频代理失败: {str(e)}")


@app.get("/api/download")
def proxy_download(url: str, title: str = "video"):
    headers = {
        "User-Agent": "Mozilla/5.0",
    }

    try:
        req = requests.get(url, headers=headers, stream=True, timeout=30)
        req.raise_for_status()

        def iterfile():
            for chunk in req.iter_content(chunk_size=1024 * 1024):
                if chunk:
                    yield chunk

        safe_title = urllib.parse.quote(title)

        return StreamingResponse(
            iterfile(),
            media_type="application/octet-stream",
            headers={
                "Content-Disposition": f"attachment; filename*=UTF-8''{safe_title}.mp4"
            },
        )

    except Exception as e:
        raise HTTPException(status_code=400, detail=f"下载失败: {str(e)}")
