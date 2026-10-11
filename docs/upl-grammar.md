# Văn phạm UPL

BTL01 - Đặc tả từ vựng và văn phạm phi ngữ cảnh.

## Quy tắc từ vựng

`ID`: `[A-Za-z]+[0-9]*`; chữ số chỉ xuất hiện ở cuối. `INTEGER`: `[0-9]+`. Phân biệt hoa/thường; từ khóa không là định danh.

Từ khóa: `begin end int bool true false if then else do while for print`. Toán tử: `= > >= == + *`. Dấu phân cách: `( ) { } ;`.

Bỏ qua khoảng trắng và comment `//`, `/* ... */`. Comment khối không lồng nhau; thiếu `*/` là lỗi. Nhận token dài nhất; cùng độ dài thì ưu tiên từ khóa.

## Văn phạm phi ngữ cảnh

`::=`: luật sinh; `|`: lựa chọn; `ε`: rỗng. Ký hiệu bắt đầu: `Program`; kết thúc đầu vào: EOF. Terminal đặt trong dấu nháy kép; `ID` và `INTEGER` là token.

```
Program ::= "begin" Statements "end"
Statements ::= Statements Statement | ε
Statement ::= Declaration ";" | Assignment ";" | IfStatement | DoStatement | ForStatement | PrintStatement
Block ::= "{" Statements "}"
Declaration ::= Type ID | Type ID "=" Expression
Type ::= "int" | "bool"
Assignment ::= ID "=" Expression
IfStatement ::= "if" "(" Expression ")" "then" Block | "if" "(" Expression ")" "then" Block "else" Block
DoStatement ::= "do" Block "while" "(" Expression ")" ";"
ForStatement ::= "for" "(" ForInit ";" Expression ";" Assignment ")" Block
ForInit ::= Declaration | Assignment
PrintStatement ::= "print" "(" Expression ")" ";"
Expression ::= Sum | Sum Comparison Sum
Comparison ::= ">" | ">=" | "=="
Sum ::= Product | Sum "+" Product
Product ::= Primary | Product "*" Primary
Primary ::= ID | INTEGER | "true" | "false" | "(" Expression ")"
```

## Quy ước cần thiết

Ưu tiên: ngoặc, `*`, `+`, so sánh. `*`, `+` kết hợp trái; so sánh không kết hợp: `a>b>c` không hợp lệ. Chương trình và khối có thể rỗng.

Đề xuất cho phần đề bài chưa quy định: hằng boolean `true`, `false`; `for` có đủ khởi tạo, điều kiện, cập nhật; thân các lệnh điều khiển luôn dùng `{ }`.

Biến phải khai báo trước khi dùng. Kiểu phải phù hợp: số học và `>`, `>=` nhận `int`; `==` nhận hai toán hạng cùng kiểu; điều kiện là `bool`. Các ràng buộc này thuộc phân tích ngữ nghĩa, chưa được parser kiểm tra.
