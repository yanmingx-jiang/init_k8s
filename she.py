#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import requests
import json
import time
# 定义接口URL
url = 'http://10.67.114.179:7861/chat/rag_offline'

# 定义要发送的数据
data = {
    "query": "你好",
    "db_name": "chroma",
    "table": "offline_cn",
    "top_k": 3,
    "distance": 3,
    # "history": [
    #     {"role": "user", "content": "我们来玩成语接龙，我先来，生龙活虎"},
    #     {"role": "assistant", "content": "虎头虎脑"}
    # ],
    "stream": True,
    "model_name": "Qwen2-7B-Instruct",
    "temperature": 0.7,
    "max_tokens": 0,
    "prompt_name": "offline_cn"
}

# 发送POST请求
headers = {
    'accept': 'application/json',
    'Content-Type': 'application/json'
}
outputs = requests.post(url, headers=headers, data=json.dumps(data))

# 打印响应状态码和响应内容
# print("Status Code:", response.status_code)
# print("Response:", response.text)
outputs.raise_for_status()
for output in outputs.iter_content(chunk_size=None, decode_unicode=True):
    print(output, end="", flush=True)
   # return Response(stream_with_context(stream_messages_from_api(ip, query)), mimetype='text/event-stream')
    # data_v = {
    #     "query": query,
    #     "db_name": "chroma",
    #     "table": "offline_cn",
    #     "top_k": 3,
    #     "distance": 3,
    #     "stream": True,
    #     "model_name": "Qwen2-7B-Instruct",
    #     "temperature": 0.7,
    #     "max_tokens": 0,
    #     "prompt_name": "offline_cn"
    #     # 注意：去除了"stream": True，因为SSE服务通常不需要这个参数
    # }

    # headers = {
    #     'accept': 'application/json',
    #     'Content-Type': 'application/json'
    # }

    # # 发送POST请求到API服务
    # response = requests.post("http://" + ip + ":7861/chat/rag_offline", headers=headers, data=json.dumps(data_v))
    # print(response)
    # # 检查响应状态码
    # response.raise_for_status()
    # for output in response.iter_content(chunk_size=None, decode_unicode=True):
    #     print(output, end="", flush=True)
    
    # if response.status_code == 200:
    #     # 如果状态码是200，则返回“成功”
    #     return jsonify({"status": "成功"}), 200
    # else:
    #     # 否则，返回“失败”和相应的状态码（这里使用了400作为示例，但您可以根据需要选择）
    #     # 注意：通常您会想返回外部API的实际状态码，但在这里为了示例，我们返回400
    #     return jsonify({"status": "失败"}), 400 