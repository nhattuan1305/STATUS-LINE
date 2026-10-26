# STATUS-LINE

Status line 4 dòng có màu cho Claude Code (bảng màu Dracula):

```
Dir: ~/projects/my-app
Model: Opus 5.5  Session ID: <uuid>
Session tokens: 6.0M (in 156 · out 76.4K · cache write 326.2K · cache read 5.6M)
Context: 25% | 5h: 75% reset 15:40 (in 4h45m) | 7d: 7% reset Jun 2 17:00 (in 1d6h)
```

- `Session tokens` cộng cả token của subagent trong session.
- Phần trăm đổi màu: xanh dưới 50%, vàng 50-79%, đỏ từ 80%.

## Cần có

- `bash` (Windows: Git Bash), `jq`, `python` hoặc `python3`.

## Cài đặt

Trong Claude Code, gõ:

```
/plugin install status-line --marketplace nhattuan1305/STATUS-LINE
```

Chọn `y` để thêm marketplace, rồi chọn scope. Sau đó chạy:

```
/status-line:install
```

Lệnh này copy script vào `~/.claude/status-line/` và đặt `statusLine` trong `~/.claude/settings.json`.
File settings cũ được backup thành `settings.json.bak-statusline-<thời gian>`.

Cài từ shell:

```
claude plugin install status-line --marketplace nhattuan1305/STATUS-LINE
```

Cập nhật plugin xong thì chạy lại `/status-line:install` để copy bản script mới.

## Gỡ

Xoá khối `statusLine` trong `~/.claude/settings.json` và thư mục `~/.claude/status-line/`.
