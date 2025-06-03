import os
import sys
import chardet
from bs4 import BeautifulSoup, NavigableString

REPLACEMENTS = [
    # 页面说明文字
    {
        "tag": "div",
        "class": "textblock",
        "contains": "Here are the classes, structs, unions and interfaces with brief descriptions:",
        "replace_with": "以下是类、结构体、联合体和接口的简要说明："
    },
    {
        "tag": "div",
        "class": "textblock",
        "contains": "Here is a list of all files with brief descriptions:",
        "replace_with": "以下是所有文件的简要说明："
    },

    # 页面标题
    {"tag": "div", "class": "title", "contains": "Main Page", "replace_with": "主页面"},
    {"tag": "div", "class": "title", "contains": "Class List", "replace_with": "类溯源"},
    {"tag": "div", "class": "title", "contains": "File List", "replace_with": "文件溯源"},
    {"tag": "h2", "class": "groupheader",  "contains": " Class Hierarchy", "replace_with": "类层次结构"},
    {"tag": "h2", "class": "groupheader",  "contains": " Class Members", "replace_with": "类成员"},
    {"tag": "h2", "class": "groupheader",  "contains": " Namespace List", "replace_with": "命名空间列表"},
    {"tag": "h2", "class": "groupheader",  "contains": " Namespace Members", "replace_with": "命名空间成员"},
    {"tag": "h2", "class": "groupheader",  "contains": " Module List", "replace_with": "模块列表"},
    {"tag": "h2", "class": "groupheader",  "contains": " Module Members", "replace_with": "模块成员"},
    {"tag": "h2", "class": "groupheader",  "contains": " File Members", "replace_with": "文件成员"},
    {"tag": "h2", "class": "groupheader",  "contains": " Functions", "replace_with": "函数"},
    {"tag": "h2", "class": "groupheader",  "contains": " Variables", "replace_with": "变量"},
    {"tag": "h2", "class": "groupheader",  "contains": " Enumerations", "replace_with": "枚举类型"},
    {"tag": "h2", "class": "groupheader",  "contains": " Enumerator", "replace_with": "枚举值"},
    {"tag": "h2", "class": "groupheader",  "contains": " Defines", "replace_with": "宏定义"},
    {"tag": "h2", "class": "groupheader",  "contains": " Typedefs", "replace_with": "类型定义"},
    {"tag": "h2", "class": "groupheader",  "contains": " Friends", "replace_with": "友元"},
    {"tag": "h2", "class": "groupheader",  "contains": " Related Functions", "replace_with": "相关函数"},
    {"tag": "h2", "class": "groupheader",  "contains": " Detailed Description", "replace_with": "详细描述"},
    {"tag": "h2", "class": "groupheader",  "contains": " Constructor & Destructor Documentation", "replace_with": "构造与析构函数文档"},
    {"tag": "h2", "class": "groupheader",  "contains": " Member Function Documentation", "replace_with": "成员函数文档"},
    {"tag": "h2", "class": "groupheader",  "contains": " Member Data Documentation", "replace_with": "成员数据文档"},
    {"tag": "h2", "class": "groupheader",  "contains": " Defines Documentation", "replace_with": "宏定义文档"},
    {"tag": "h2", "class": "groupheader",  "contains": " Typedef Documentation", "replace_with": "类型定义文档"},
    {"tag": "h2", "class": "groupheader",  "contains": " Enumeration Type Documentation", "replace_with": "枚举类型文档"},
    {"tag": "h2", "class": "groupheader",  "contains": " Enumerator Documentation", "replace_with": "枚举值文档"},
    {"tag": "h2", "class": "groupheader",  "contains": " Variable Documentation", "replace_with": "变量文档"},
    {"tag": "h2", "class": "groupheader",  "contains": " Function Documentation", "replace_with": "函数文档"},

    # 页脚版权等
    {"tag": "p", "class": "footer", "contains": "Copyright", "replace_with": "版权所有"},
    {"tag": "p", "class": "footer", "contains": "Generated on", "replace_with": "生成日期"},
]

def detect_encoding(file_path, sample_size=10000):
    """检测文件编码"""
    with open(file_path, 'rb') as f:
        rawdata = f.read(sample_size)
    result = chardet.detect(rawdata)
    encoding = result['encoding']
    if not encoding:
        encoding = 'utf-8'  # 默认utf-8
    return encoding

def replace_in_html(file_path):
    encoding = detect_encoding(file_path)
    try:
        with open(file_path, 'r', encoding=encoding, errors='ignore') as f:
            soup = BeautifulSoup(f, 'html.parser')
    except Exception as e:
        print(f"[ERROR] 读取文件 {file_path} 时出错: {e}")
        return

    changed = False

    for rule in REPLACEMENTS:
        tag = rule.get("tag", True)
        attrs = {}
        if "class" in rule:
            attrs["class"] = rule["class"]
        if "id" in rule:
            attrs["id"] = rule["id"]

        for el in soup.find_all(tag, attrs=attrs):
            html_content = el.decode_contents()
            if rule["contains"] in html_content:
                el.clear()
                el.append(NavigableString(rule["replace_with"]))
                print(f"[INFO] 替换成功: {rule['contains']} -> {rule['replace_with']} in {file_path}")
                changed = True

    if changed:
        try:
            with open(file_path, 'w', encoding=encoding, errors='ignore') as f:
                f.write(str(soup))
        except Exception as e:
            print(f"[ERROR] 写入文件 {file_path} 时出错: {e}")

def walk_and_process(root_dir):
    for root, _, files in os.walk(root_dir):
        for name in files:
            if name.endswith(".html"):
                replace_in_html(os.path.join(root, name))

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 replace_html.py <html_root_dir>")
        sys.exit(1)
    walk_and_process(sys.argv[1])