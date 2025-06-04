import os
import xml.etree.ElementTree as ET
from collections import defaultdict
import argparse
import json

def analyze_doxygen_xml(xml_dir: str):
    func_info = {}
    reverse_calls = defaultdict(list)

    for fname in os.listdir(xml_dir):
        if not fname.endswith(".xml"):
            continue

        fpath = os.path.join(xml_dir, fname)
        try:
            tree = ET.parse(fpath)
            root = tree.getroot()
        except Exception as e:
            print(f"[WARN] 无法解析 XML 文件: {fpath}, 错误: {e}")
            continue

        for memberdef in root.findall(".//memberdef[@kind='function']"):
            name = memberdef.findtext('name')
            if not name:
                continue

            location = memberdef.find('location')
            decl_file = location.attrib.get('file', '') if location is not None else ''
            decl_line = location.attrib.get('line', '') if location is not None else ''
            body_file = location.attrib.get('bodyfile', '') if location is not None else ''
            body_line = location.attrib.get('bodystart', '') if location is not None else ''

            # 替换为映射后的路径（比如 /opt/output -> /files）
            adjusted_path = fpath.replace("/opt/output", "/files")

            # 初始化函数信息
            if name not in func_info:
                func_info[name] = {
                    "function": name,
                    "declaration": f"{decl_file}:{decl_line}" if decl_file else "unknown",
                    "definition": f"{body_file}:{body_line}" if body_file else "unknown",
                    "calls": [],
                    "called_by": [],
                    "call_count": 0,
                    "called_count": 0,
                    "xml_file": adjusted_path
                }

            # 当前函数调用了哪些函数
            for ref in memberdef.findall("references"):
                callee = ref.text
                if callee and callee != name:
                    func_info[name]["calls"].append(callee)
                    reverse_calls[callee].append(name)

            # 当前函数被哪些函数调用
            for ref_by in memberdef.findall("referencedby"):
                caller = ref_by.text
                if caller and caller != name:
                    func_info[name]["called_by"].append(caller)
                    reverse_calls[name].append(caller)

    # 更新调用次数统计
    for name, data in func_info.items():
        data["call_count"] = len(set(data["calls"]))
        data["called_count"] = len(set(data["called_by"] + reverse_calls.get(name, [])))

    # 处理未定义但被调用的函数
    for func, callers in reverse_calls.items():
        if func not in func_info:
            func_info[func] = {
                "function": func,
                "declaration": "unknown",
                "definition": "unknown",
                "calls": [],
                "called_by": list(set(callers)),
                "call_count": 0,
                "called_count": len(set(callers)),
                "xml_file": "unknown"
            }

    return list(func_info.values())

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
