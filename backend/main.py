from fastapi import FastAPI, HTTPException
from fastapi.responses import StreamingResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import re
import urllib.parse
import yt_dlp
import subprocess
import json
import requests

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 允许所有域名跨域，方便 Flutter Web 访问
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class ExtractRequest(BaseModel):
    url_text: str

@app.post("/api/extract")
def extract_video(request: ExtractRequest):
    # Extract url from text (basic regex)
    url_pattern = re.compile(r'http[s]?://(?:[a-zA-Z]|[0-9]|[$-_@.&+]|[!*\(\),]|(?:%[0-9a-fA-F][0-9a-fA-F]))+')
    urls = url_pattern.findall(request.url_text)
    
    if not urls:
        raise HTTPException(status_code=400, detail="No valid URL found in text")
    
    target_url = urls[0]
    
    ydl_opts = {
        'format': 'best',
        'quiet': True,
        'no_warnings': True,
        'extract_flat': True, # 如果是列表，仅提取不深入
        'nocheckcertificate': True,
        'noplaylist': True,
    }
    
    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(target_url, download=False)
            return {
                "title": info.get("title", "未命名视频"),
                "cover_url": info.get("thumbnail", "https://storage.googleapis.com/gtv-videos-bucket/sample/images/BigBuckBunny.jpg"),
                "video_url": info.get("url", "")
            }
    except Exception as e:
        error_msg = str(e)
        # 终极黑客方案：发现 you-get 太慢，对于 B站 直接采用官方 HTML5 隐藏接口进行毫秒级免登提取！
        if "bilibili" in target_url:
            try:
                # 提取 bvid
                bvid_match = re.search(r'BV[a-zA-Z0-9]+', target_url)
                if not bvid_match:
                    raise Exception("无法从链接中提取 BVID")
                bvid = bvid_match.group(0)
                
                headers = {
                    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
                    'Referer': 'https://www.bilibili.com/'
                }
                
                # 1. 毫秒级获取视频详情
                info_url = f"https://api.bilibili.com/x/web-interface/view?bvid={bvid}"
                res = requests.get(info_url, headers=headers).json()
                if res['code'] != 0:
                    raise Exception(f"B站API拦截: {res['message']}")
                    
                cid = res['data']['cid']
                title = res['data']['title']
                cover = res['data']['pic']
                
                # 2. 毫秒级获取无水印播放流 (强行伪装 html5 绕过 WBI)
                play_url = f"https://api.bilibili.com/x/player/playurl?bvid={bvid}&cid={cid}&qn=16&platform=html5&high_quality=1"
                res_play = requests.get(play_url, headers=headers).json()
                
                if res_play['code'] != 0:
                    raise Exception("播放流获取失败")
                    
                video_url = res_play['data']['durl'][0]['url']
                
                return {
                    "title": title,
                    "cover_url": cover, 
                    "video_url": video_url
                }
            except Exception as fast_api_err:
                error_msg += f" | 极速官方接口也失败: {str(fast_api_err)}"
                
        raise HTTPException(status_code=400, detail=f"提取失败: {error_msg}")

@app.get("/api/download")
def proxy_download(url: str, title: str = "video"):
    """
    流式代理下载接口：
    接收视频直链，通过后端请求并强制附加 Content-Disposition: attachment 头，
    从而绕过浏览器的默认播放行为，实现直接下载。
    """
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        'Referer': 'https://www.bilibili.com/'
    }
    
    try:
        req = requests.get(url, headers=headers, stream=True)
        req.raise_for_status()
        
        def iterfile():
            for chunk in req.iter_content(chunk_size=1024 * 1024): # 1MB chunks
                if chunk:
                    yield chunk

        # 解决中文文件名的编码问题
        encoded_title = urllib.parse.quote(title)
        return StreamingResponse(
            iterfile(), 
            media_type="application/octet-stream", # 强制设为二进制流，防止浏览器解析播放
            headers={
                "Content-Disposition": f"attachment; filename*=UTF-8''{encoded_title}.mp4"
            }
        )
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"代理下载失败: {str(e)}")
