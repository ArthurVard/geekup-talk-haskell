import System.Random
import Control.Applicative
import Control.Monad
import Data.List
import Data.NumInstances -- to allow (1,1) + (2,2)
import Data.Char

type Name   = String
type Score  = Int
type Choose = Int

data QuizNode = Quiz Name [QuizNode]
                | Section       Name Score        [QuizNode]
                | RandomSection Name Score Choose [QuizNode]
                | Question      Name Score         Answer
    deriving Show

data Answer = MultiChoice  [BoolAnswer]
            | StringChoice [String]
    deriving Show

data BoolAnswer = BoolAnswer { 
        boolAnswerCorrect  :: Bool,
        boolAnswerText     :: String
    } 
    deriving Show

-- *************
-- MAIN function
--  prepare the version of the quiz that we'll take (by "stamping" it)
--  then pass that to the takeQuiz routine
--  this is all in the IO monad, as 
-- a) stamp uses random numers, and b) takeQuiz has Input/Output
--

main :: IO ()
main = stamp quiz >>= takeQuiz

-- *************
-- define the quiz
-- 
quiz,geo,pop :: QuizNode
quiz = Quiz "General Knowledge Quiz" [ pop, geo ]

geo = RandomSection "Geography" 40 2 [
    Question "What is the capital of England?" 2 $ StringChoice ["London"],
    Question "What is the capital of France?"  2 $ StringChoice ["Paris"],
    Question "What is the capital of Finland?" 2 $ StringChoice ["Helsinki"],
    Question "What is the capital of Germany?" 2 $ StringChoice ["Berlin"],
    Question "What is the capital of Italy?"   2 $ StringChoice ["Rome", "Roma"]
    ]

pop = Section "Pop music" 60 [
    Question "Which of these are Beatles?" 5
        $ MultiChoice [
            y "John",
            y "Paul",
            y "George",
            y "Ringo",
            n "Bob",
            n "Jason" ],
    Question "Which of these are Sugababes?" 5
        $ MultiChoice [
            y "Heidi",
            y "Amelle",
            y "Jade",
            n "Tracy",
            n "Shirley" ]
        ]

y,n :: String -> BoolAnswer
y = BoolAnswer True
n = BoolAnswer False

-- *************
-- Functions to prepare and take the quiz
-- 

-- "stamps" a variant of the quiz, ready to be allocated to a quiz-taker.
stamp :: QuizNode -> IO QuizNode
stamp (Quiz s ns)              = Quiz    s   <$> mapM stamp ns
stamp (Section s i ns)         = Section s i <$> mapM stamp ns
stamp q@(Question _ _ _)       = return q
stamp (RandomSection s i r ns) = do selected <- pickN r ns 
                                    Section s i <$> mapM stamp selected

-- using record syntax, as we'll use completedNodeScore accessor later!
data CompletedNode =  CompletedNode 
    { 
        completedNodeDesc       :: String,
    completedNodeScore      :: (Int,Int),
    completedNodeChildren   :: [CompletedNode],
    completedNodeQuizNode :: QuizNode 
} deriving Show

-- takeQuiz runs the quiz taking, and shows a summary
-- takeNode recurses down the quiz tree, prompting the user for Questions

takeQuiz :: QuizNode -> IO ()
takeQuiz quiz@(Quiz s _)        = do
    result <- takeNode quiz
    let score = completedNodeScore result
    putStrLn $ "In the quiz '" ++ s ++ "', you scored "
        ++ (showPercent score)
takeQuiz _ = error "takeQuiz expects a Quiz value"

showPercent :: (Int, Int) -> [Char]
showPercent (i, 100) = (show i) ++ "%"
-- NB: not defined for fractions not over 100, we could convert those

takeNode :: QuizNode -> IO CompletedNode
takeNode node@(Quiz    s ns)   = takeNode' node s 100 ns
takeNode node@(Section s i ns) = takeNode' node s i   ns
takeNode (RandomSection _ _ _ _) = 
    error "Can't take a RandomSection, stamp the quiz first"
takeNode node@(Question s i a) = do
    printQuestion node
    ans <- getLine
    let correct = checkAnswer ans a
    let score = if correct then (i,i) else (0,i)
    putStrLn $ if correct then "Correct!" else "Wrong!"
    return $ CompletedNode ans score [] node

takeNode' :: QuizNode -> Name -> Int -> [QuizNode] -> IO CompletedNode
takeNode' node s i ns = do
    cs <- mapM takeNode ns
    let (score, total) = sum $ map completedNodeScore cs
    let score' = (i * score) `div` total
    return $ CompletedNode s (score',i) cs node

printQuestion :: QuizNode -> IO ()
printQuestion (Question s i (MultiChoice bs)) = do
    putStrLn s
    putStrLn $ showBoolTextAnswers bs
    putStr "> "
printQuestion (Question s _ _) = do
    putStrLn s
    putStr "> "

numberMulti :: [b] -> [(Int, b)]
numberMulti = zip [1..]

showBoolTextAnswers :: [BoolAnswer] -> String
showBoolTextAnswers bs =
    let ns  = numberMulti bs
        ns' = map (\a -> intercalate ""
                         ["\t", 
                          show . fst $ a, 
                          ". ", 
                          boolAnswerText . snd $ a]
                  ) ns
    in unlines ns'

checkAnswer :: String -> Answer -> Bool
checkAnswer s (StringChoice ss) = s `elem` ss
-- checkAnswer s (StringChoice ss) = any ((=~) s) ss -- if ss contains regexps!
checkAnswer s (MultiChoice ss) = 
    let user    = parseMultiChoices s
        correct = getCorrectAnswers ss
    in user == correct

parseMultiChoices :: String -> [Int]
parseMultiChoices = 
    let op `on` p = (\a b -> p a `op` p b)
    in sort .
       nub  .
       map read .
       filter (isDigit . head) .
       groupBy ((==) `on` isDigit)

getCorrectAnswers :: [BoolAnswer] -> [Int]
getCorrectAnswers = map fst .
             filter (boolAnswerCorrect . snd) .
             numberMulti

-- from http://greenokapi.net/blog/2007/09/06/more-random-fun/
pickN :: Int -> [a] -> IO [a]
pickN n xs = let len = length xs 
             in  pickN' n len xs

pickN' :: Int -> Int -> [a] -> IO [a] 
pickN' n l []     = do return [] 
pickN' n l (x:xs) = do b <- roll n l 
                       if b then do xs <- pickN' (n-1) (l-1) xs 
                                    return (x:xs)
                       else pickN' n (l-1) xs

roll :: (Random a, Ord a, Num a) => a -> a -> IO Bool
roll p q = do r <- getStdRandom (randomR (1,q)) 
              return $ r <= p
