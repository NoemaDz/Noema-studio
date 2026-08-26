import json
import os

def build_workflow():
    workflow_path = 'assets/workflows/ip_adapter_api.json'
    out_path = 'assets/workflows/multi_character_api.json'
    
    with open(workflow_path, 'r') as f:
        wf = json.load(f)
    
    # Remove old IP Adapter nodes
    if '10' in wf: del wf['10']
    if '12' in wf: del wf['12']
    
    # 300: Background Mask
    wf['300'] = {
        "class_type": "SolidMask",
        "inputs": {
            "value": 0.0,
            "width": 768,
            "height": 512
        },
        "_meta": {"title": "Background Mask"}
    }
    
    # Characters setup
    for i in range(1, 4):
        # Image loader
        wf[f'10{i}'] = {
            "class_type": "LoadImage",
            "inputs": {
                "image": "character.png",
                "upload": "image"
            },
            "_meta": {"title": f"Character Image {i}"}
        }
        
        # Region Mask
        wf[f'30{i}'] = {
            "class_type": "SolidMask",
            "inputs": {
                "value": 1.0,
                "width": 256,
                "height": 512
            },
            "_meta": {"title": f"Region Mask {i}"}
        }
        
        # Composite
        wf[f'20{i}'] = {
            "class_type": "MaskComposite",
            "inputs": {
                "destination": ["300", 0],
                "source": [f"30{i}", 0],
                "x": (i-1)*256,
                "y": 0,
                "operation": "add"
            },
            "_meta": {"title": f"Composite Mask {i}"}
        }
        
        # IPAdapter
        prev_model = ["2", 0] if i == 1 else [f"12{i-1}", 0]
        wf[f'12{i}'] = {
            "class_type": "IPAdapterAdvanced",
            "inputs": {
                "weight": 0.0,
                "weight_type": "linear",
                "combine_embeds": "concat",
                "start_at": 0.0,
                "end_at": 1.0,
                "embeds_scaling": "V only",
                "model": prev_model,
                "ipadapter": ["11", 1],
                "image": [f"10{i}", 0],
                "attn_mask": [f"20{i}", 0]
            },
            "_meta": {"title": f"IPAdapter Advanced {i}"}
        }
        
    # Update connections to point to 123
    wf['5']['inputs']['model'] = ["123", 0]
    wf['14']['inputs']['model'] = ["123", 0]
    wf['15']['inputs']['model'] = ["123", 0]
    
    with open(out_path, 'w') as f:
        json.dump(wf, f, indent=2)

if __name__ == '__main__':
    build_workflow()
