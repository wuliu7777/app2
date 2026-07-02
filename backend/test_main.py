import unittest
from pathlib import Path
import sys
import types

sys.modules.setdefault("yt_dlp", types.SimpleNamespace(YoutubeDL=object))
sys.path.insert(0, str(Path(__file__).resolve().parent))
from main import find_first_url


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


if __name__ == "__main__":
    unittest.main()
