import unittest
from pathlib import Path
import sys
import types

sys.modules.setdefault("yt_dlp", types.SimpleNamespace(YoutubeDL=object))
sys.path.insert(0, str(Path(__file__).resolve().parent))
from main import (
    extract_bilibili_video,
    extract_bvid,
    extract_douyin_aweme_id,
    extract_douyin_video,
    extract_douyin_webpage_video,
    find_first_url,
    is_douyin_url,
)


class UrlExtractionTests(unittest.TestCase):
    def test_extracts_plain_url(self):
        self.assertEqual(
            find_first_url("https://v.douyin.com/abc123/"),
            "https://v.douyin.com/abc123/",
        )

    def test_strips_chinese_share_punctuation(self):
        self.assertEqual(
            find_first_url("复制这条视频 https://v.douyin.com/abc123/，打开抖音看看"),
            "https://v.douyin.com/abc123/",
        )

    def test_strips_wrapping_punctuation(self):
        self.assertEqual(
            find_first_url("视频链接（https://example.com/watch?id=1）。"),
            "https://example.com/watch?id=1",
        )


class FakeResponse:
    def __init__(self, url, payload=None):
        self.url = url
        self._payload = payload or {}

    def json(self):
        return self._payload

    def raise_for_status(self):
        return None


class FakeHttpClient:
    def __init__(self):
        self.calls = []

    def get(self, url, **kwargs):
        self.calls.append((url, kwargs))
        if "x/web-interface/view" in url:
            return FakeResponse(
                url,
                {
                    "code": 0,
                    "data": {
                        "cid": 456,
                        "title": "B站测试视频",
                        "pic": "https://i0.hdslb.com/test.jpg",
                    },
                },
            )
        if "x/player/playurl" in url:
            return FakeResponse(
                url,
                {
                    "code": 0,
                    "data": {
                        "durl": [
                            {"url": "https://upos-sz-mirrorcos.bilivideo.com/test.mp4"}
                        ]
                    },
                },
            )
        return FakeResponse("https://www.bilibili.com/video/BV1xx411c7mD/")


class FakeTextResponse(FakeResponse):
    def __init__(self, url, text):
        super().__init__(url)
        self.text = text


class FakeDouyinHttpClient:
    def __init__(self, page_html):
        self.page_html = page_html
        self.calls = []

    def get(self, url, **kwargs):
        self.calls.append((url, kwargs))
        if url == "https://v.douyin.com/abc123/":
            return FakeResponse("https://www.douyin.com/video/7312345678901234567")
        return FakeTextResponse(url, self.page_html)


class BilibiliExtractionTests(unittest.TestCase):
    def test_extracts_bvid_from_bilibili_url(self):
        self.assertEqual(
            extract_bvid("https://www.bilibili.com/video/BV1xx411c7mD/?spm_id_from=333"),
            "BV1xx411c7mD",
        )

    def test_bilibili_api_result_uses_backend_stream_proxy(self):
        result = extract_bilibili_video(
            "https://www.bilibili.com/video/BV1xx411c7mD/",
            http_client=FakeHttpClient(),
        )

        self.assertEqual(result["title"], "B站测试视频")
        self.assertEqual(result["cover_url"], "https://i0.hdslb.com/test.jpg")
        self.assertIn("/api/stream?", result["video_url"])
        self.assertIn("source_url", result)


class DouyinExtractionTests(unittest.TestCase):
    def test_identifies_douyin_urls(self):
        self.assertTrue(is_douyin_url("https://www.douyin.com/video/123456"))
        self.assertTrue(is_douyin_url("https://v.douyin.com/abc123/"))
        self.assertFalse(is_douyin_url("https://www.bilibili.com/video/BV1xx411c7mD/"))

    def test_douyin_short_url_resolves_before_ytdlp(self):
        parsed_urls = []

        def fake_parser(url):
            parsed_urls.append(url)
            return {
                "title": "抖音测试视频",
                "cover_url": "https://example.com/cover.jpg",
                "video_url": "https://example.com/video.mp4",
                "source_url": url,
            }

        result = extract_douyin_video(
            "https://v.douyin.com/abc123/",
            http_client=FakeHttpClient(),
            parser=fake_parser,
        )

        self.assertEqual(parsed_urls, ["https://www.bilibili.com/video/BV1xx411c7mD/"])
        self.assertEqual(result["platform"], "douyin")
        self.assertEqual(result["title"], "抖音测试视频")

    def test_extracts_aweme_id_from_douyin_url(self):
        self.assertEqual(
            extract_douyin_aweme_id("https://www.douyin.com/video/7312345678901234567"),
            "7312345678901234567",
        )

    def test_extracts_douyin_video_from_render_data(self):
        page_html = (
            '<script id="RENDER_DATA" type="application/json">'
            "%7B%22video%22%3A%7B%22desc%22%3A%22%E6%8A%96%E9%9F%B3%E9%A1%B5%E9%9D%A2%E8%A7%86%E9%A2%91%22%2C"
            "%22video%22%3A%7B%22play_addr%22%3A%7B%22url_list%22%3A%5B%22https%3A%2F%2Fv26-web.douyinvod.com%2Fvideo.mp4%22%5D%7D%2C"
            "%22cover%22%3A%7B%22url_list%22%3A%5B%22https%3A%2F%2Fexample.com%2Fcover.jpg%22%5D%7D%7D%7D%7D"
            "</script>"
        )

        result = extract_douyin_webpage_video(
            "https://www.douyin.com/video/7312345678901234567",
            http_client=FakeDouyinHttpClient(page_html),
        )

        self.assertEqual(result["title"], "抖音页面视频")
        self.assertEqual(result["cover_url"], "https://example.com/cover.jpg")
        self.assertIn("/api/stream?", result["video_url"])
        self.assertEqual(result["platform"], "douyin")

    def test_douyin_falls_back_to_webpage_when_ytdlp_fails(self):
        page_html = (
            '<script id="RENDER_DATA" type="application/json">'
            "%7B%22aweme%22%3A%7B%22desc%22%3A%22%E5%85%9C%E5%BA%95%E8%A7%86%E9%A2%91%22%2C"
            "%22video%22%3A%7B%22download_addr%22%3A%7B%22url_list%22%3A%5B%22https%3A%2F%2Fv3-web.douyinvod.com%2Ffallback.mp4%22%5D%7D%7D%7D%7D"
            "</script>"
        )

        def failing_parser(url):
            raise Exception("unsupported url")

        result = extract_douyin_video(
            "https://v.douyin.com/abc123/",
            http_client=FakeDouyinHttpClient(page_html),
            parser=failing_parser,
        )

        self.assertEqual(result["title"], "兜底视频")
        self.assertIn("/api/stream?", result["video_url"])


if __name__ == "__main__":
    unittest.main()
