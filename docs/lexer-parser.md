# Lexer và parser đã cài đặt

Tài liệu này mô tả những gì `src/specs/lexer.l` và `src/specs/parser.y` đang làm, và so sánh với yêu cầu trong `upl-grammar.md

## 1. Cách chạy

Bộ phân tích dùng `grmtools` (`lrlex`, `lrpar` 0.15). `src/build.rs` sinh lexer và parser từ hai file đặc tả lúc biên dịch.

``` sh
cargo run --offline < program.txt            # phân tích cú pháp
cargo run --offline -- --tokens < program.txt # chỉ in dãy token
```

- Đầu vào hợp lệ: in `ok`, trả mã 0.
- Đầu vào sai: in vị trí lỗi và các cách sửa đề xuất, trả mã 1.
- Parser dùng chế độ `NoAction`: chỉ kiểm tra cú pháp, **chưa tạo AST**.

## 2–3. Lexer và parser

Đã chuyển sang `docs/spec/`: mỗi tag `@doc:` trong mã nguồn có một file riêng (Definition + Intention). Xem `docs/spec/README.md`.

## 4. Kiểm tra đã chạy

Ngày 2026-11-11, `cargo build` thành công. Chương trình sau in `ok`:

``` text
mod m { fn f(a: int, b: bool,) -> int { let mut x: int = a + 2 * 3; while x > 0 { x = x - 1; } if b { return x; } else { 0 } } }
struct P { x: int, y: bool, }
impl P { fn g() { for i in 0..10 { a::b(i)[0].c; } loop { break; } } }
use a::b;
let z: int = 1; /* c */ // d
```

`fn f() { a < b < c; }` bị báo lỗi, đúng với quy tắc so sánh không kết hợp.

## 6. Vấn đề đã biết

- Với `--tokens`, nhiều từ khóa (ví dụ `fn`) và `ID` in tên là `?` thay vì tên token. Phần phân tích cú pháp không bị ảnh hưởng.
- Chưa có phân tích ngữ nghĩa: không kiểm tra biến đã khai báo hay kiểu phù hợp.
