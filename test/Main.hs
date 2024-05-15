{-# LANGUAGE OverloadedStrings #-}
module Main (main) where
import Test.Hspec
import MyLib
main :: IO ()
main = hspec $ do
    describe "MExpr Parsing" $ do
        it "empty" $ do
            parse "" `shouldBe` Right []
        it "strings" $ do
            parse "\"hello, world\"" `shouldBe` Right [String "hello, world"]
        it "block" $ do
            parse "[1;2;3]" `shouldBe` Right [Block [Number 1, Number 2, Number 3]]
        it "nested block" $ do
            parse "[[];[[]]]" `shouldBe` Right [Block [Block[], Block[Block[]]]]
        it "atom" $ do
            parse "foo" `shouldBe` Right [Atom "foo"]
        it "Compounds simple" $ do
            let mexpr = parse "a b c" 
            mexpr `shouldBe` Right [Compound [Atom "a", Atom "b", Atom "c"]]
            (mexpr >>= traverse macroExpand) `shouldBe` Right [Apply (Apply (Atom "a") (Atom "b")) (Atom "c")]
        it "Compounds with blocks" $ do
            let mexpr = parse "f [g a]"
            mexpr `shouldBe` Right [Compound[Atom "f", Block [Compound[Atom "g", Atom "a"]]]]
            (mexpr >>= traverse macroExpand) `shouldBe` Right [Apply (Atom "f") (Block[Apply (Atom "g") (Atom "a")])]
        it "Compounds with operators" $ do
            let mexpr = parse "f a + g b + h c"
            mexpr `shouldBe` Right [Compound[Atom "f", Atom "a", Operator "+", Atom "g", Atom "b", Operator "+", Atom "h", Atom "c"]]
            (mexpr >>= traverse macroExpand) `shouldBe` Right [Binary (Apply (Atom "f") (Atom "a")) (Operator "+") (Binary (Apply (Atom "g") (Atom "b")) (Operator "+") (Apply (Atom "h") (Atom "c")))]
    describe "Realistic Parsing" $ do
        it "multiple statements" $ do
            let mexpr = parse "let x = 1\nlet y = 2\nx + y"
            mexpr `shouldBe` Right [Compound[Atom "let", Atom "x", Operator "=", Number 1], Compound[Atom "let", Atom "y", Operator "=", Number 2], Compound[Atom "x", Operator "+", Atom "y"]]
            (mexpr >>= traverse macroExpand) `shouldBe` Right [Apply (Atom "let") (Block [Binary (Atom "x") (Operator "=") (Number 1)]), Apply (Atom "let") (Block [Binary (Atom "y") (Operator "=") (Number 2)]), Binary (Atom "x") (Operator "+") (Atom "y")]
        it "increment" $ do
            let mexpr = parse "let incr = x -> x + 1"
            mexpr `shouldBe` Right [Compound[Atom "let", Atom "incr", Operator "=", Atom "x", Operator "->", Atom "x", Operator "+", Number 1]]
            (mexpr >>= traverse macroExpand) `shouldBe` Right [Apply (Atom "let") (Block [Binary (Atom "incr") (Operator "=") (Binary (Atom "x") (Operator "->") (Binary (Atom "x") (Operator "+") (Number 1)))])]
        it "factorial" $ do
            let mexpr = parse "let factorial = {\n\t0 -> 1;\n\tx -> x * factorial (x - 1)}"
            mexpr `shouldBe` Right [Compound [Atom "let", Atom "factorial", Operator "=", Block [Compound [Number 0, Operator "->", Number 1], Compound [Atom "x", Operator "->", Atom "x", Operator "*", Atom "factorial", Compound [Atom "x", Operator "-", Number 1]]]]]
            (mexpr >>= traverse macroExpand) `shouldBe` Right 
                [ Apply 
                    (Atom "let") 
                    (Block 
                        [ Binary 
                            (Atom "factorial") 
                            (Operator "=") 
                            (Block 
                                [ Binary
                                    (Number 0.0) 
                                    (Operator "->") 
                                    (Number 1.0)
                                , Binary 
                                    (Atom "x") 
                                    (Operator "->") 
                                    (Binary 
                                        (Atom "x") 
                                        (Operator "*") 
                                        (Apply 
                                            (Atom "factorial") 
                                            (Binary 
                                                (Atom "x") 
                                                (Operator "-") 
                                                (Number 1.0))))
                                ])
                        ])
                ]
        it "mutual recursion" $ do
            let mexpr = parse "let [isOdd = { 1 -> true; x -> not (isEven (x - 1))}; isEven = {0 -> true; x -> not (isOdd (x - 1))}]"
            mexpr `shouldBe` Right [Compound [Atom "let",Block [Compound [Atom "isOdd",Operator "=",Block [Compound [Number 1.0,Operator "->",Atom "true"],Compound [Atom "x",Operator "->",Atom "not",Compound [Atom "isEven",Compound [Atom "x",Operator "-",Number 1.0]]]]],Compound [Atom "isEven",Operator "=",Block [Compound [Number 0.0,Operator "->",Atom "true"],Compound [Atom "x",Operator "->",Atom "not",Compound [Atom "isOdd",Compound [Atom "x",Operator "-",Number 1.0]]]]]]]]
            (mexpr >>= traverse macroExpand) `shouldBe` Right 
                [ Apply 
                    (Atom "let") 
                    (Block 
                        [ Binary 
                            (Atom "isOdd") 
                            (Operator "=") 
                            (Block 
                                [ Binary 
                                    (Number 1.0) 
                                    (Operator "->") 
                                    (Atom "true")
                                , Binary 
                                    (Atom "x") 
                                    (Operator "->") 
                                    (Apply 
                                        (Atom "not") 
                                        (Apply 
                                            (Atom "isEven") 
                                            (Binary 
                                                (Atom "x") 
                                                (Operator "-") 
                                                (Number 1.0))))
                                ])
                        , Binary 
                            (Atom "isEven") 
                            (Operator "=") 
                            (Block 
                                [ Binary 
                                    (Number 0.0) 
                                    (Operator "->") 
                                    (Atom "true")
                                , Binary 
                                    (Atom "x") 
                                    (Operator "->")
                                    (Apply 
                                        (Atom "not") 
                                        (Apply 
                                            (Atom "isOdd") 
                                            (Binary 
                                                (Atom "x") 
                                                (Operator "-") 
                                                (Number 1.0))))
                                ])
                        ])

                ]