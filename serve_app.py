from fastapi import FastAPI
from pydantic import BaseModel
from ray import serve
import subprocess, glob, os, time, base64

app = FastAPI()

class GenReq(BaseModel):
    prompt: str
    size: str = "1280*704"
    ckpt_dir: str = "/models/Wan2.2-TI2V-5B"

@serve.deployment(ray_actor_options={"num_gpus": 1})
@serve.ingress(app)
class WanHandler:
    @app.post("/generate")
    def generate(self, req: GenReq):
        cmd = [
            "python","/app/Wan2.2/generate.py",
            "--task","ti2v-5B",
            "--size", req.size,
            "--ckpt_dir", req.ckpt_dir,
            "--offload_model","True","--convert_model_dtype","--t5_cpu",
            "--prompt", req.prompt
        ]
        subprocess.run(cmd, check=True)

        time.sleep(1)
        vids = sorted(glob.glob("/app/Wan2.2/outputs/**/*.mp4", recursive=True), key=os.path.getmtime)
        with open(vids[-1], "rb") as f:
            b64 = base64.b64encode(f.read()).decode()
        return {"video_b64": b64}

app = WanHandler.bind()
