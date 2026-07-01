from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import re

app = FastAPI()

class ExtractRequest(BaseModel):
    url_text: str

@app.post("/api/extract")
def extract_video(request: ExtractRequest):
    # Extract url from text (basic regex)
    url_pattern = re.compile(r'http[s]?://(?:[a-zA-Z]|[0-9]|[$-_@.&+]|[!*\(\),]|(?:%[0-9a-fA-F][0-9a-fA-F]))+')
    urls = url_pattern.findall(request.url_text)
    
    if not urls:
        raise HTTPException(status_code=400, detail="No valid URL found in text")
    
    # In a real app, you would pass urls[0] to a real parser (like Douyin_TikTok_Download_API).
    # Here we return a mock response with a valid test video URL.
    return {
        "title": "测试视频 - 这是一个演示",
        "cover_url": "https://storage.googleapis.com/gtv-videos-bucket/sample/images/BigBuckBunny.jpg",
        "video_url": "https://storage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
    }
