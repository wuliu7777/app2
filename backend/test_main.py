import unittest
from pathlib import Path
import sys
import types

sys.modules.setdefault("yt_dlp", types.SimpleNamespace(YoutubeDL=object))
sys.path.insert(0, str(Path(__file__).resolve().parent))
from main import extract_bilibili_video, extract_bvid, find_first_url


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


if __name__ == "__main__":
    unittest.main()
