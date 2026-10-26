%grmtools{yacckind: Grmtools}
%start Program
%%
Program -> ItemList;
If -> 'if' Expr Block
			| 'if' Expr Block 'else' Block
			| 'if' Expr Block 'else' If;
ItemList -> ItemList Item | Item;
Item -> Function | Struct | Impl | Import | Mod | GlobalLet;
Struct -> 'struct' ID '{' StructFields '}' | 'struct' ID '{' '}';
StructFields -> StructFields ',' ID ':' Type | ID ':' Type;
%%
