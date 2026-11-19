# Wildcards 词库

兼容 `__name__` 随机替换：
- `__style__` 会随机读取 `style.txt` 的一行
- 支持子目录：`__art/color__` -> `art/color.txt`
- 支持嵌套：选中的行里还可以有 `__lighting__`
- 支持内联选择：`{red|blue|green}`

阿美每次“换一组”都会重新展开，所以每次组合不同。
