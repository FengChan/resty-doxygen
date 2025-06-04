import os
import xml.etree.ElementTree as ET
from collections import defaultdict
import argparse
import json

def analyze_doxygen_xml(xml_dir: str):
    func_calls = defaultdict(int)
    func_definitions = {}

    for root_dir, _, files in os.walk(xml_dir):
        for fname in files:
            if not fname.endswith(".xml"):
                continue

            fpath = os.path.join(root_dir, fname)
            try:
                tree = ET.parse(fpath)
                root = tree.getroot()
            except Exception as e:
                print(f"[WARN] 无法解析 XML 文件: {fpath}, 错误: {e}")
                continue

            for memberdef in root.findall(".//memberdef[@kind='function']"):
                func_name = memberdef.findtext('name')
                if not func_name:
                    continue

                location = memberdef.find('location')
                file_line = "unknown"
                if location is not None:
                    file_line = f"{location.attrib.get('file', '')}:{location.attrib.get('line', '')}"

                func_definitions[func_name] = file_line

                # 统计被调用次数（有多少函数调用了该函数）
                for refby in memberdef.findall('referencedby'):
                    caller = refby.text
                    if caller:
                        func_calls[func_name] += 1

    results = []
    all_funcs = set(func_definitions.keys()) | set(func_calls.keys())
    for func in sorted(all_funcs):
        results.append({
            "function": func,
            "calls": func_calls.get(func, 0),
            "location": func_definitions.get(func, "unknown")
        })

    return results

def export_json(results, path):
    with open(path, "w", encoding="utf-8") as f:
        json.dump(results, f, indent=2, ensure_ascii=False)
    print(f"✅ 已导出 JSON 文件：{path}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="分析 Doxygen XML，输出 JSON 格式函数调用统计")
    parser.add_argument("xml_dir", help="Doxygen 生成的 XML 文件夹路径")
    parser.add_argument("--json", required=True, help="输出 JSON 文件路径")
    args = parser.parse_args()

    results = analyze_doxygen_xml(args.xml_dir)
    export_json(results, args.json)
