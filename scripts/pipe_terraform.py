#!/usr/bin/env python3
"""
Terraform実行結果をファイルに保存するスクリプト
標準ライブラリのみを使用
# # planの実行と記録
# python pipe_terraform.py plan -var-file=dev.tfvars

# # applyの実行と記録
# python pipe_terraform.py apply -auto-approve -var-file=dev.tfvars

# # destroyの実行と記録
# python pipe_terraform.py destroy -var-file=dev.tfvars

# # initの実行と記録
# python pipe_terraform.py init
"""

import subprocess
import sys
import os
from datetime import datetime
from pathlib import Path


def get_timestamp():
    """タイムスタンプを取得"""
    return datetime.now().strftime("%Y%m%d_%H%M%S")


def get_output_dir():
    """出力ディレクトリを取得（なければ作成）"""
    output_dir = Path("terraform_logs")
    output_dir.mkdir(exist_ok=True)
    return output_dir


def run_terraform(command: list[str]) -> tuple[int, str, str]:
    """
    Terraformコマンドを実行し、結果を返す
    
    Args:
        command: terraformコマンドと引数のリスト
    
    Returns:
        (終了コード, stdout, stderr)
    """
    # terraformを先頭に追加
    full_command = ["terraform"] + command
    
    print(f"実行中: {' '.join(full_command)}")
    print("-" * 50)
    
    process = subprocess.Popen(
        full_command,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1,
    )
    
    stdout_lines = []
    stderr_lines = []
    
    # リアルタイムで出力を表示しながら収集
    while True:
        stdout_line = process.stdout.readline()
        stderr_line = process.stderr.readline()
        
        if stdout_line:
            print(stdout_line, end="")
            stdout_lines.append(stdout_line)
        if stderr_line:
            print(stderr_line, end="", file=sys.stderr)
            stderr_lines.append(stderr_line)
        
        if process.poll() is not None:
            # 残りの出力を読み取る
            for line in process.stdout:
                print(line, end="")
                stdout_lines.append(line)
            for line in process.stderr:
                print(line, end="", file=sys.stderr)
                stderr_lines.append(line)
            break
    
    return process.returncode, "".join(stdout_lines), "".join(stderr_lines)


def save_result(command: list[str], returncode: int, stdout: str, stderr: str):
    """
    実行結果をファイルに保存
    
    Args:
        command: 実行したコマンド
        returncode: 終了コード
        stdout: 標準出力
        stderr: 標準エラー出力
    """
    output_dir = get_output_dir()
    timestamp = get_timestamp()
    
    # コマンド名を取得（plan, apply, destroy など）
    cmd_name = command[0] if command else "unknown"
    
    # ファイル名を生成
    filename = f"{timestamp}_{cmd_name}.log"
    filepath = output_dir / filename
    
    # 現在のディレクトリ情報
    cwd = os.getcwd()
    
    # 結果をファイルに書き込み
    with open(filepath, "w", encoding="utf-8") as f:
        f.write("=" * 60 + "\n")
        f.write(f"Terraform実行ログ\n")
        f.write("=" * 60 + "\n\n")
        
        f.write(f"日時: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write(f"作業ディレクトリ: {cwd}\n")
        f.write(f"コマンド: terraform {' '.join(command)}\n")
        f.write(f"終了コード: {returncode}\n")
        f.write(f"ステータス: {'成功' if returncode == 0 else 'エラー'}\n")
        f.write("\n")
        
        f.write("-" * 60 + "\n")
        f.write("STDOUT:\n")
        f.write("-" * 60 + "\n")
        f.write(stdout if stdout else "(出力なし)\n")
        f.write("\n")
        
        if stderr:
            f.write("-" * 60 + "\n")
            f.write("STDERR:\n")
            f.write("-" * 60 + "\n")
            f.write(stderr)
            f.write("\n")
    
    print("\n" + "=" * 50)
    print(f"ログを保存しました: {filepath}")
    
    return filepath


def main():
    """メイン関数"""
    if len(sys.argv) < 2:
        print("使用方法: python pipe_terraform.py <terraform引数...>")
        print("例:")
        print("  python pipe_terraform.py plan -var-file=dev.tfvars")
        print("  python pipe_terraform.py apply -auto-approve")
        print("  python pipe_terraform.py destroy -var-file=dev.tfvars")
        sys.exit(1)
    
    # terraformに渡す引数を取得
    terraform_args = sys.argv[1:]
    
    # Terraformを実行
    returncode, stdout, stderr = run_terraform(terraform_args)
    
    # 結果を保存
    save_result(terraform_args, returncode, stdout, stderr)
    
    # Terraformの終了コードをそのまま返す
    sys.exit(returncode)


if __name__ == "__main__":
    main()