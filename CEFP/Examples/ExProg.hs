module Main where

import qualified Prelude
import MuFeldspar.Prelude

import MuFeldspar.Core
import MuFeldspar.Frontend
import MuFeldspar.Vector

import Imperative.Imperative
import Imperative.Compiler

import Data.Word
import Data.Bits (Bits)


type VecBool = Vector (Data Bool)

type VecInt = Vector (Data Int)

-- Primitive Functions (and tuples)

prog0 :: Data Int -> Data Int
prog0 = (*2)

prog1 :: (Data Int, Data Int) -> (Data Int, Data Int, Data Int)
prog1 (a,b) = (min a b, a + b, a ^ b)

prog2 :: Data Int -> Data Int -> (Data Int, Data Int, Data Int)
prog2 a b = (min a b, a + b, a ^ b)

isEven :: (Type a, Integral a) => Data a -> Data Bool
isEven i = i `mod` 2 == 0

swap (a,b) = (b,a)


-- Conditional

f :: Data Int -> Data Int
f i = (isEven i) ? (2*i, i)

t1 = eval (f 3)

t2 = eval (f 4)


-- Arrays

prog3 :: Data [Int]
prog3 = parallel 10 (*2)

tst1 = eval prog3

tst1a = drawFeld prog3

tst1b = printFeld prog3

tst1c = compile prog3

prog4 :: Data [Int]
prog4 = parallel 10 (`mod` 5)

prog5 :: Data [Int]
prog5 = parallel 10 f

prog6 :: Data [Int]
prog6 = parallel 10 (<< 3)

prog7 :: Data [Int]
prog7 = parallel 10 (>> 1)

prog8 :: Data [Int]
prog8 = parallel 12 (`xor` 3)




perm f arr = parallel (getLength arr) (\i -> getIx arr (f i))

rot arr = perm f arr
  where
    f i = (i+1) `mod` (getLength arr)

prog9 :: Data [[Int]]
prog9 = parallel 8 (\i -> parallel i id)

-- Sequential Arrays

prog10 :: Data [Int]
prog10 = sequential 10 1 g
  where
    g ix st = (j,j) 
      where j = (ix + 1)  * st

-- for Loop

prog11 :: Data Int -> Data Int
prog11 k  = forLoop k 1 g
  where
    g ix st = (ix + 1) * st

composeN :: (Syntax st) => (st -> st) -> Data Length -> st -> st
composeN f l i0 = forLoop l i0 g
  where
    g _ i = f i

ccn = compile (composeN ((*2) :: Data Int -> Data Int))





-- Vectors

prog12 :: Vector (Data Int)
prog12 = Indexed 10 (*2)

tst2 = eval prog11

prog13 :: Data Int
prog13 = sum $ Indexed 10 (*2)


prog14 :: Vector (Data Int)
prog14 = map (*5) $ Indexed 10 (*2)

prog15 :: Vector (Data Int)
prog15 = map (*5) . map (+1) $ Indexed 10 (*2)

scalarProduct :: (Type a, Num a) => Vector (Data a) -> Vector (Data a) -> Data a
scalarProduct as bs = sum $ zipWith (*) as bs


forceEx as bs = (sum . force) $ zipWith (*) as bs

prog16 :: Data Int -> Data Int
prog16 a = sum $ (isEven a) ? (prog14, prog15)





sumEven :: VecInt -> Data Int
sumEven = sum . map zeroOutOdd
  where
    zeroOutOdd x = (testBit x 0) ? (0,x)

{--
*Main> eval $ sumEven (value [1..10])
30
--}




tri :: (Syntax a) => (a -> a)  -> Vector a -> Vector a
tri f (Indexed len ixf) = (indexed len ixf')
  where
    ixf' i = composeN f i (ixf i)

ctri = compile (tri ((*2) :: Data Int -> Data Int))


testBit :: (Type a, Bits a) => Data a -> Data Index -> Data Bool
testBit l i = not ((l .&. (1<<i)) == 0)


int2BL :: (Type a, Bits a)  =>  Data a -> VecBool
int2BL l = reverse $ indexed (bitSize l) (testBit l)


int2BLN :: Data Length -> Data Int -> VecBool
int2BLN n v = reverse $ indexed n (testBit v)


pows2 :: Data Length -> Vector (Data Index)
pows2 k = Indexed k (1<<)

bL2Int :: VecBool -> Data Int
bL2Int bs = scalarProduct (reverse (map b2i bs)) (pows2 (length bs))

bL2Int' :: VecBool -> Data Int
bL2Int' = sum . tri (*2) . map b2i

oneBitsN :: Data Index -> Data Index
oneBitsN  = complement . zeroBitsN

zeroBitsN :: Data Index -> Data Index
zeroBitsN = shiftL allOnes

allOnes :: Data Index
allOnes = complement 0



xorBool :: Data Bool -> Data Bool -> Data Bool
xorBool a b = not (a == b)

pad :: Data Length -> VecBool -> VecBool
pad l v = (replicate (l - length v) false) ++ v

crcAdd :: VecBool -> VecBool -> VecBool
crcAdd as bs = zipWith xorBool (pad m as) (pad m bs)
  where
    m = max (length as) (length bs)




simpleCRC :: VecBool -> VecBool -> VecBool
simpleCRC poly msg =  fst $ composeN step (l+w) (fw, msg ++ fw)
  where
    w = length poly
    fw = replicate w false
    l = length msg
    step (reg,ms) = (reg',tlms)
      where
        reg' = (index reg 0) ? (zipWith xorBool poly r1, r1)
        (hms,tlms) = splitAt 1 ms
        r1 = drop 1 reg ++ hms

simpleCRC1 :: VecBool -> VecBool -> VecBool
simpleCRC1 poly msg =  fst $ composeN step (length augmsg) (fw,0)
  where
    w = length poly
    fw = replicate w false
    augmsg = msg ++ fw
    step (reg,i) = (reg',i+1)
      where
        reg' = (index reg 0) ? (zipWith xorBool poly r1, r1)
        r1 = drop 1 reg ++ replicate 1 (index augmsg i)

simpleCRC2 :: VecBool -> VecBool -> VecBool
simpleCRC2 poly msg = forLoop (length augmsg) fw step
  where
    w = length poly
    fw = replicate w false
    augmsg = msg ++ fw
    step i reg = reg'
      where
        reg' = (index reg 0) ? (zipWith xorBool poly r1, r1)
        r1 = drop 1 reg ++ replicate 1 (index augmsg i)


crc16ccitt :: Data Word16
crc16ccitt = value 0x1021

crc32ieee :: Data Word32
crc32ieee = value 0x04C11DB7

tst4 = eval $ int2BL crc16ccitt

tstSimpleCRC = eval $ simpleCRC2 (int2BL crc16ccitt) (int2BL (8856 :: Data Word64))

{--
*Main> tstSimpleCRC
[False,True,True,False,False,False,True,False,False,False,True,True,False,True,False,True]
--}

tstSimpleCRCAgain = eval $ simpleCRC2 (int2BL crc16ccitt) (int2BL (8856 :: Data Word64) ++ value [False,True,True,False,False,False,True,False,False,False,True,True,False,True,False,True])

{--
*Main> tstSimpleCRCAgain
[False,False,False,False,False,False,False,False,False,False,False,False,False,False,False,False]
--}

table :: (Bits a, Type a) => Data a -> Data Index -> Data [a]
table poly size = parallel (2^size) (calc poly size)


calc :: (Bits a, Type a) => Data a -> Data Index -> Data Index -> Data a
calc poly size i = i2n $ bL2Int $ simpleCRC1 (int2BL poly) (int2BLN size i)


mTable :: (Type a, Bits a) => Data a -> Data Index -> Data Index -> Data [a]
mTable poly size i = parallel (2^size) (\j -> calc poly (j `shiftL` (8*i)) size)

calc1 :: Data Index -> Data [Word32]
calc1 i = parallel 256 (\j -> tableCRCModCh (bytesR (j `shiftL` (8*i))))

table32 :: Data [Word32]
table32 = table  crc32ieee 8

table16 :: Data [Word16]
table16 = table crc16ccitt 8

tstTab16 = eval $ table16

{--
*Main> tstTab16
[0,4129,8258,12387,16516,20645,24774,28903,33032,37161,41290,45419,49548,53677,5
7806,61935,4657,528,12915,8786,21173,17044,29431,25302,37689,33560,45947,41818,5
4205,50076,62463,58334,9314,13379,1056,5121,25830,29895,17572,21637,42346,46411,
34088,38153,58862,62927,50604,54669,13907,9842,5649,1584,30423,26358,22165,18100
,46939,42874,38681,34616,63455,59390,55197,51132,18628,22757,26758,30887,2112,62
41,10242,14371,51660,55789,59790,63919,35144,39273,43274,47403,23285,19156,31415
,27286,6769,2640,14899,10770,56317,52188,64447,60318,39801,35672,47931,43802,278
14,31879,19684,23749,11298,15363,3168,7233,60846,64911,52716,56781,44330,48395,3
6200,40265,32407,28342,24277,20212,15891,11826,7761,3696,65439,61374,57309,53244
,48923,44858,40793,36728,37256,33193,45514,41451,53516,49453,61774,57711,4224,16
1,12482,8419,20484,16421,28742,24679,33721,37784,41979,46042,49981,54044,58239,6
2302,689,4752,8947,13010,16949,21012,25207,29270,46570,42443,38312,34185,62830,5
8703,54572,50445,13538,9411,5280,1153,29798,25671,21540,17413,42971,47098,34713,
38840,59231,63358,50973,55100,9939,14066,1681,5808,26199,30326,17941,22068,55628
,51565,63758,59695,39368,35305,47498,43435,22596,18533,30726,26663,6336,2273,144
66,10403,52093,56156,60223,64286,35833,39896,43963,48026,19061,23124,27191,31254
,2801,6864,10931,14994,64814,60687,56684,52557,48554,44427,40424,36297,31782,276
55,23652,19525,15522,11395,7392,3265,61215,65342,53085,57212,44955,49082,36825,4
0952,28183,32310,20053,24180,11923,16050,3793,7920]
--}

tab16 = value [0,4129,8258,12387,16516,20645,24774,28903,33032,37161,41290,45419,49548,53677,57806,61935,4657,528,12915,8786,21173,17044,29431,25302,37689,33560,45947,41818,54205,50076,62463,58334,9314,13379,1056,5121,25830,29895,17572,21637,42346,46411,34088,38153,58862,62927,50604,54669,13907,9842,5649,1584,30423,26358,22165,18100,46939,42874,38681,34616,63455,59390,55197,51132,18628,22757,26758,30887,2112,6241,10242,14371,51660,55789,59790,63919,35144,39273,43274,47403,23285,19156,31415,27286,6769,2640,14899,10770,56317,52188,64447,60318,39801,35672,47931,43802,27814,31879,19684,23749,11298,15363,3168,7233,60846,64911,52716,56781,44330,48395,36200,40265,32407,28342,24277,20212,15891,11826,7761,3696,65439,61374,57309,53244,48923,44858,40793,36728,37256,33193,45514,41451,53516,49453,61774,57711,4224,161,12482,8419,20484,16421,28742,24679,33721,37784,41979,46042,49981,54044,58239,62302,689,4752,8947,13010,16949,21012,25207,29270,46570,42443,38312,34185,62830,58703,54572,50445,13538,9411,5280,1153,29798,25671,21540,17413,42971,47098,34713,38840,59231,63358,50973,55100,9939,14066,1681,5808,26199,30326,17941,22068,55628,51565,63758,59695,39368,35305,47498,43435,22596,18533,30726,26663,6336,2273,14466,10403,52093,56156,60223,64286,35833,39896,43963,48026,19061,23124,27191,31254,2801,6864,10931,14994,64814,60687,56684,52557,48554,44427,40424,36297,31782,27655,23652,19525,15522,11395,7392,3265,61215,65342,53085,57212,44955,49082,36825,40952,28183,32310,20053,24180,11923,16050,3793,7920] :: Data [Word16]

tstTab32 = eval $ table32

{--
*Main> tstTab32
[0,79764919,159529838,222504665,319059676,398814059,445009330,507990021,63811935
2,583659535,797628118,726387553,890018660,835552979,1015980042,944750013,1276238
704,1221641927,1167319070,1095957929,1595256236,1540665371,1452775106,1381403509
,1780037320,1859660671,1671105958,1733955601,2031960084,2111593891,1889500026,19
52343757,2552477408,2632100695,2443283854,2506133561,2334638140,2414271883,21919
15858,2254759653,3190512472,3135915759,3081330742,3009969537,2905550212,28509594
11,2762807018,2691435357,3560074640,3505614887,3719321342,3648080713,3342211916,
3287746299,3467911202,3396681109,4063920168,4143685023,4223187782,4286162673,377
9000052,3858754371,3904687514,3967668269,881225847,809987520,1023691545,96923409
4,662832811,591600412,771767749,717299826,311336399,374308984,453813921,53357647
0,25881363,88864420,134795389,214552010,2023205639,2086057648,1897238633,1976864
222,1804852699,1867694188,1645340341,1724971778,1587496639,1516133128,1461550545
,1406951526,1302016099,1230646740,1142491917,1087903418,2896545431,2825181984,27
70861561,2716262478,3215044683,3143675388,3055782693,3001194130,2326604591,23894
56536,2200899649,2280525302,2578013683,2640855108,2418763421,2498394922,37699005
19,3832873040,3912640137,3992402750,4088425275,4151408268,4197601365,4277358050,
3334271071,3263032808,3476998961,3422541446,3585640067,3514407732,3694837229,364
0369242,1762451694,1842216281,1619975040,1682949687,2047383090,2127137669,193846
8188,2001449195,1325665622,1271206113,1183200824,1111960463,1543535498,148906962
9,1434599652,1363369299,622672798,568075817,748617968,677256519,907627842,853037
301,1067152940,995781531,51762726,131386257,177728840,240578815,269590778,349224
269,429104020,491947555,4046411278,4126034873,4172115296,4234965207,3794477266,3
874110821,3953728444,4016571915,3609705398,3555108353,3735388376,3664026991,3290
680682,3236090077,3449943556,3378572211,3174993278,3120533705,3032266256,2961025
959,2923101090,2868635157,2813903052,2742672763,2604032198,2683796849,2461293480
,2524268063,2284983834,2364738477,2175806836,2238787779,1569362073,1498123566,14
09854455,1355396672,1317987909,1246755826,1192025387,1137557660,2072149281,21351
22070,1912620623,1992383480,1753615357,1816598090,1627664531,1707420964,29539018
5,358241886,404320391,483945776,43990325,106832002,186451547,266083308,932423249
,861060070,1041341759,986742920,613929101,542559546,756411363,701822548,33161969
85,3244833742,3425377559,3370778784,3601682597,3530312978,3744426955,3689838204,
3819031489,3881883254,3928223919,4007849240,4037393693,4100235434,4180117107,425
9748804,2310601993,2373574846,2151335527,2231098320,2596047829,2659030626,247035
9227,2550115596,2947551409,2876312838,2788305887,2733848168,3165939309,309470716
2,3040238851,2985771188]
--}

tab32 = value [0,79764919,159529838,222504665,319059676,398814059,445009330,507990021,638119352,583659535,797628118,726387553,890018660,835552979,1015980042,944750013,1276238704,1221641927,1167319070,1095957929,1595256236,1540665371,1452775106,1381403509,1780037320,1859660671,1671105958,1733955601,2031960084,2111593891,1889500026,1952343757,2552477408,2632100695,2443283854,2506133561,2334638140,2414271883,2191915858,2254759653,3190512472,3135915759,3081330742,3009969537,2905550212,2850959411,2762807018,2691435357,3560074640,3505614887,3719321342,3648080713,3342211916,3287746299,3467911202,3396681109,4063920168,4143685023,4223187782,4286162673,3779000052,3858754371,3904687514,3967668269,881225847,809987520,1023691545,969234094,662832811,591600412,771767749,717299826,311336399,374308984,453813921,533576470,25881363,88864420,134795389,214552010,2023205639,2086057648,1897238633,1976864222,1804852699,1867694188,1645340341,1724971778,1587496639,1516133128,1461550545,1406951526,1302016099,1230646740,1142491917,1087903418,2896545431,2825181984,2770861561,2716262478,3215044683,3143675388,3055782693,3001194130,2326604591,2389456536,2200899649,2280525302,2578013683,2640855108,2418763421,2498394922,3769900519,3832873040,3912640137,3992402750,4088425275,4151408268,4197601365,4277358050,3334271071,3263032808,3476998961,3422541446,3585640067,3514407732,3694837229,3640369242,1762451694,1842216281,1619975040,1682949687,2047383090,2127137669,1938468188,2001449195,1325665622,1271206113,1183200824,1111960463,1543535498,1489069629,1434599652,1363369299,622672798,568075817,748617968,677256519,907627842,853037301,1067152940,995781531,51762726,131386257,177728840,240578815,269590778,349224269,429104020,491947555,4046411278,4126034873,4172115296,4234965207,3794477266,3874110821,3953728444,4016571915,3609705398,3555108353,3735388376,3664026991,3290680682,3236090077,3449943556,3378572211,3174993278,3120533705,3032266256,2961025959,2923101090,2868635157,2813903052,2742672763,2604032198,2683796849,2461293480,2524268063,2284983834,2364738477,2175806836,2238787779,1569362073,1498123566,1409854455,1355396672,1317987909,1246755826,1192025387,1137557660,2072149281,2135122070,1912620623,1992383480,1753615357,1816598090,1627664531,1707420964,295390185,358241886,404320391,483945776,43990325,106832002,186451547,266083308,932423249,861060070,1041341759,986742920,613929101,542559546,756411363,701822548,3316196985,3244833742,3425377559,3370778784,3601682597,3530312978,3744426955,3689838204,3819031489,3881883254,3928223919,4007849240,4037393693,4100235434,4180117107,4259748804,2310601993,2373574846,2151335527,2231098320,2596047829,2659030626,2470359227,2550115596,2947551409,2876312838,2788305887,2733848168,3165939309,3094707162,3040238851,2985771188] :: Data [Word32]

leftByte ::  (Bits a, Type a, Integral a) => Data a -> Data Index
leftByte a = i2n $ (a `shiftR` (bitSize a - 8)) .&. 0xFF

byteIn :: (Bits a, Type a, Integral a) => Data Word8 -> Data a -> Data a
byteIn b w = w `shiftL` 8 .|. i2n b


tableCRC :: (Bits a, Type a, Integral a) =>
            Data a -> Vector (Data Word8) -> Data a
tableCRC poly msg = forLoop (length augmsg) 0 step
  where
    augmsg = msg ++ replicate ((bitSize poly) `div` 8) 0
    step i reg
      = byteIn (index augmsg i) reg `xor` getIx (table poly 8) (leftByte reg)


tableCRC1 :: (Bits a, Type a, Integral a) =>
             Data a -> Vector (Data Word8) -> Data a
tableCRC1 poly msg = share (value (eval (table poly 8))) $ \tab ->
                     forLoop (length augmsg) 0 (step tab)
  where
    augmsg = msg ++ replicate ((bitSize poly) `div` 8) 0
    step tab i reg
      = byteIn (index augmsg i) reg `xor` getIx tab (leftByte reg)

tstTabCRC = compile $ tableCRC1 crc16ccitt

{--
main (v0)
  v1 := [0,4129,8258,12387,16516,20645,24774,28903,33032,37161,41290,45419,49548
,53677,57806,61935,4657,528,12915,8786,21173,17044,29431,25302,37689,33560,45947
,41818,54205,50076,62463,58334,9314,13379,1056,5121,25830,29895,17572,21637,4234
6,46411,34088,38153,58862,62927,50604,54669,13907,9842,5649,1584,30423,26358,221
65,18100,46939,42874,38681,34616,63455,59390,55197,51132,18628,22757,26758,30887
,2112,6241,10242,14371,51660,55789,59790,63919,35144,39273,43274,47403,23285,191
56,31415,27286,6769,2640,14899,10770,56317,52188,64447,60318,39801,35672,47931,4
3802,27814,31879,19684,23749,11298,15363,3168,7233,60846,64911,52716,56781,44330
,48395,36200,40265,32407,28342,24277,20212,15891,11826,7761,3696,65439,61374,573
09,53244,48923,44858,40793,36728,37256,33193,45514,41451,53516,49453,61774,57711
,4224,161,12482,8419,20484,16421,28742,24679,33721,37784,41979,46042,49981,54044
,58239,62302,689,4752,8947,13010,16949,21012,25207,29270,46570,42443,38312,34185
,62830,58703,54572,50445,13538,9411,5280,1153,29798,25671,21540,17413,42971,4709
8,34713,38840,59231,63358,50973,55100,9939,14066,1681,5808,26199,30326,17941,220
68,55628,51565,63758,59695,39368,35305,47498,43435,22596,18533,30726,26663,6336,
2273,14466,10403,52093,56156,60223,64286,35833,39896,43963,48026,19061,23124,271
91,31254,2801,6864,10931,14994,64814,60687,56684,52557,48554,44427,40424,36297,3
1782,27655,23652,19525,15522,11395,7392,3265,61215,65342,53085,57212,44955,49082
,36825,40952,28183,32310,20053,24180,11923,16050,3793,7920] :: [Word16]
  x3 := v0
  x2 := (arrLength x3)
  x6 := 4129 :: Word16
  x5 := (bitSize x6)
  x7 := 8 :: Int
  x4 := (div x5 x7)
  x1 := (x2 + x4)
  x8 := 0 :: Word16
  x9 := 0 :: Int
  v3 := (tup2 x8 x9)

  for v2 in 0 .. (x1-1) do
    x14 := v3
    x13 := (sel1 x14)
    x15 := 8 :: Int
    x12 := (shiftL x13 x15)
    x20 := v3
    x19 := (sel2 x20)
    x22 := v0
    x21 := (arrLength x22)
    x18 := (x19 < x21)

    if x18 then
      x23 := v0
      x25 := v3
      x24 := (sel2 x25)
      x17 := (getIx x23 x24)
    else
      x17 := 0 :: Word8
    x16 := (i2n x17)
    x11 := (x12 .|. x16)
    x27 := v1
    x32 := v3
    x31 := (sel1 x32)
    x36 := v3
    x35 := (sel1 x36)
    x34 := (bitSize x35)
    x37 := 8 :: Int
    x33 := (x34 - x37)
    x30 := (shiftR x31 x33)
    x38 := 255 :: Word16
    x29 := (x30 .&. x38)
    x28 := (i2n x29)
    x26 := (getIx x27 x28)
    x10 := (xor x11 x26)
    x41 := v3
    x40 := (sel2 x41)
    x42 := 1 :: Int
    x39 := (x40 + x42)
    v3 := (tup2 x10 x39)
  x0 := v3
  out := (sel1 x0)
--}


tableCRC2 :: Vector (Data Word8) -> Data Word16
tableCRC2 msg = share tab16 $ \tab -> fst (composeN (step tab) (length augmsg) (0,0))
  where
    augmsg = msg ++ replicate 2 0
    step tab (reg, i) = (byteIn (index augmsg i) reg `xor` getIx  tab (leftByte reg), i+1)


tstFastTab = compile tableCRC2

tableCRC3 :: Vector (Data Word8) -> Data Word32
tableCRC3 msg = share tab32 $ \tab -> fst (composeN (step tab) (length augmsg) (0,0))
  where
    augmsg = msg ++ replicate 4 0
    step tab (reg, i) = (byteIn (index augmsg i) reg `xor` getIx  tab (leftByte reg), i+1)


tableCRCMod :: (Bits a, Type a, Integral a) =>
               Data a -> Vector (Data Word8) -> Data a
tableCRCMod poly msg = share (value (eval (table poly 8))) $ \tab ->
                       forLoop (length msg) 0 (step tab)
  where
    step tab i reg
      = reg `shiftL` 8  `xor` getIx tab (leftByte reg `xor` i2n (index msg i))

tableCRCModCh :: Vector (Data Word8) -> Data Word32
tableCRCModCh msg = share tab32 $ \tab -> forLoop (length msg) 0 (step tab)
  where
    step tab i reg
      = reg `shiftL` 8  `xor` getIx tab (leftByte reg `xor` i2n (index msg i))

tstModTab = compile $ tableCRCMod crc16ccitt

{--
main (v0)
  v1 := [0,4129,8258,12387,16516,20645,24774,28903,33032,37161,41290,45419,49548
,53677,57806,61935,4657,528,12915,8786,21173,17044,29431,25302,37689,33560,45947
,41818,54205,50076,62463,58334,9314,13379,1056,5121,25830,29895,17572,21637,4234
6,46411,34088,38153,58862,62927,50604,54669,13907,9842,5649,1584,30423,26358,221
65,18100,46939,42874,38681,34616,63455,59390,55197,51132,18628,22757,26758,30887
,2112,6241,10242,14371,51660,55789,59790,63919,35144,39273,43274,47403,23285,191
56,31415,27286,6769,2640,14899,10770,56317,52188,64447,60318,39801,35672,47931,4
3802,27814,31879,19684,23749,11298,15363,3168,7233,60846,64911,52716,56781,44330
,48395,36200,40265,32407,28342,24277,20212,15891,11826,7761,3696,65439,61374,573
09,53244,48923,44858,40793,36728,37256,33193,45514,41451,53516,49453,61774,57711
,4224,161,12482,8419,20484,16421,28742,24679,33721,37784,41979,46042,49981,54044
,58239,62302,689,4752,8947,13010,16949,21012,25207,29270,46570,42443,38312,34185
,62830,58703,54572,50445,13538,9411,5280,1153,29798,25671,21540,17413,42971,4709
8,34713,38840,59231,63358,50973,55100,9939,14066,1681,5808,26199,30326,17941,220
68,55628,51565,63758,59695,39368,35305,47498,43435,22596,18533,30726,26663,6336,
2273,14466,10403,52093,56156,60223,64286,35833,39896,43963,48026,19061,23124,271
91,31254,2801,6864,10931,14994,64814,60687,56684,52557,48554,44427,40424,36297,3
1782,27655,23652,19525,15522,11395,7392,3265,61215,65342,53085,57212,44955,49082
,36825,40952,28183,32310,20053,24180,11923,16050,3793,7920] :: [Word16]
  x1 := v0
  x0 := (arrLength x1)
  v3 := 0 :: Word16

  for v2 in 0 .. (x0-1) do
    x3 := v3
    x4 := 8 :: Int
    x2 := (shiftL x3 x4)
    x6 := v1
    x11 := v3
    x14 := v3
    x13 := (bitSize x14)
    x15 := 8 :: Int
    x12 := (x13 - x15)
    x10 := (shiftR x11 x12)
    x16 := 255 :: Word16
    x9 := (x10 .&. x16)
    x8 := (i2n x9)
    x19 := v0
    x20 := v2
    x18 := (getIx x19 x20)
    x17 := (i2n x18)
    x7 := (xor x8 x17)
    x5 := (getIx x6 x7)
    v3 := (xor x2 x5)
  out := v3
--}

bytes :: (Bits t, Type t, Integral t) => Data t -> Vector (Data Word8)
bytes w = map i2n (Indexed l ixf)
  where
    ixf k = (w `shiftR` (8*k)) .&. 0xFF
    l = numBytes w


bytesR :: (Bits t, Type t, Integral t) => Data t -> Vector (Data Word8)
bytesR w = map i2n (Indexed l ixf)
  where
    ixf k = (w `shiftR` (8*(l-1-k))) .&. 0xFF
    l = numBytes w

numBytes :: (Bits t, Type t, Integral t) => Data t -> Data Index
numBytes a = (bitSize a) `div` 8


m1 = eval $ tableCRCMod crc32ieee (value [1..20])

{--
*Main> m1
3245827117
--}

m2 = eval $ tableCRCMod crc32ieee (value [1..20] ++ bytesR (3245827117 :: Data Word32))

{--
*Main> m2
0
--}

sliceCRC :: (Type a, Bits a, Integral a) =>
             Data a -> Vector (Data a) -> Data a
sliceCRC poly msg = share (value (eval (parallel n (mTable poly 8)))) $ \tab ->
                    forLoop (length msg) 0 (step tab)
  where
    n = numBytes poly
    step tab i reg  = fold xor 0 $ g . bytes $ reg `xor` w1
      where
        w1 = index msg i
        g (Indexed len ixf) = Indexed len ixf'
           where
             ixf' j = getIx (getIx tab j) (i2n (ixf j))




m3 = eval $ sliceCRC crc16ccitt (value [1..5])


sliceCRC' :: Vector (Data Word32) -> Data Word32
sliceCRC' msg = share (value (eval (parallel 4 calc1))) $ \tab ->
                forLoop (length msg) 0 (step tab)
  where
    step tab i reg = fold xor 0 $ g . bytes $ reg `xor` w1
      where
        w1 = index msg i
        g (Indexed len ixf) = Indexed len ixf'
           where
             ixf' j = getIx (getIx tab j) (i2n (ixf j))


fold1 :: (Syntax a) => (a -> a -> a) -> Vector a -> a
fold1 f as = fold f (index as 0) (drop 1 as)

m4 = eval $ sliceCRC' (value [1..100])
{--
*Main> m4
3886779157
--}

m5 = eval $ sliceCRC' (value [1..5] ++ replicate 1 3886779157)

m6 = eval $ sliceCRC' (value [1..100] ++ replicate 1 4076606085)

{--
main (v0)
  v1 := [[0,79764919,159529838,222504665,319059676,398814059,445009330,507990021
,638119352,583659535,797628118,726387553,890018660,835552979,1015980042,94475001
3,1276238704,1221641927,1167319070,1095957929,1595256236,1540665371,1452775106,1
381403509,1780037320,1859660671,1671105958,1733955601,2031960084,2111593891,1889
500026,1952343757,2552477408,2632100695,2443283854,2506133561,2334638140,2414271
883,2191915858,2254759653,3190512472,3135915759,3081330742,3009969537,2905550212
,2850959411,2762807018,2691435357,3560074640,3505614887,3719321342,3648080713,33
42211916,3287746299,3467911202,3396681109,4063920168,4143685023,4223187782,42861
62673,3779000052,3858754371,3904687514,3967668269,881225847,809987520,1023691545
,969234094,662832811,591600412,771767749,717299826,311336399,374308984,453813921
,533576470,25881363,88864420,134795389,214552010,2023205639,2086057648,189723863
3,1976864222,1804852699,1867694188,1645340341,1724971778,1587496639,1516133128,1
461550545,1406951526,1302016099,1230646740,1142491917,1087903418,2896545431,2825
181984,2770861561,2716262478,3215044683,3143675388,3055782693,3001194130,2326604
591,2389456536,2200899649,2280525302,2578013683,2640855108,2418763421,2498394922
,3769900519,3832873040,3912640137,3992402750,4088425275,4151408268,4197601365,42
77358050,3334271071,3263032808,3476998961,3422541446,3585640067,3514407732,36948
37229,3640369242,1762451694,1842216281,1619975040,1682949687,2047383090,21271376
69,1938468188,2001449195,1325665622,1271206113,1183200824,1111960463,1543535498,
1489069629,1434599652,1363369299,622672798,568075817,748617968,677256519,9076278
42,853037301,1067152940,995781531,51762726,131386257,177728840,240578815,2695907
78,349224269,429104020,491947555,4046411278,4126034873,4172115296,4234965207,379
4477266,3874110821,3953728444,4016571915,3609705398,3555108353,3735388376,366402
6991,3290680682,3236090077,3449943556,3378572211,3174993278,3120533705,303226625
6,2961025959,2923101090,2868635157,2813903052,2742672763,2604032198,2683796849,2
461293480,2524268063,2284983834,2364738477,2175806836,2238787779,1569362073,1498
123566,1409854455,1355396672,1317987909,1246755826,1192025387,1137557660,2072149
281,2135122070,1912620623,1992383480,1753615357,1816598090,1627664531,1707420964
,295390185,358241886,404320391,483945776,43990325,106832002,186451547,266083308,
932423249,861060070,1041341759,986742920,613929101,542559546,756411363,701822548
,3316196985,3244833742,3425377559,3370778784,3601682597,3530312978,3744426955,36
89838204,3819031489,3881883254,3928223919,4007849240,4037393693,4100235434,41801
17107,4259748804,2310601993,2373574846,2151335527,2231098320,2596047829,26590306
26,2470359227,2550115596,2947551409,2876312838,2788305887,2733848168,3165939309,
3094707162,3040238851,2985771188],[0,3524903388,2700254735,1928028115,1159995817
,2537414773,3856056230,936345210,2319991634,1481736846,716889437,4171439233,3479
986939,494248743,1872690420,3179756840,273783571,3259521743,2963473692,165640723
2,1433778874,2272033638,4119274677,664724841,2585385025,1207966109,988497486,390
8208530,3745380840,220477492,2144298983,2916525627,547567142,4072339450,21528351
13,1380477429,1703352207,3080640083,3312814464,392972380,2867557748,2029171880,1
69470843,3623889575,4023342301,1037473025,1329449682,2636385038,821210421,380707
9657,2415932218,1108996838,1976994972,2815380800,3575911059,121492303,3132812903
,1755525051,440954984,3360797108,4288597966,763825682,1600934337,2373292061,1095
134284,2472521104,3786732099,866988959,73551333,3598421049,2760954858,1988694582
,3406704414,420998850,1811722513,3118821581,2385120951,1546899307,785944760,4240
527716,1360525151,2198746755,4058343760,603760780,338941686,3324647210,303256600
9,1725466917,3680482317,155612625,2074946050,2847206366,2658899364,1281512568,10
49168811,3968911991,1642420842,3019676598,3239560293,319686073,616659907,4141398
559,2217993676,1445602320,3953989944,968153316,1264551735,2571519723,2928228497,
2089875789,242984606,3697436482,1907671417,2746024101,3511050102,56598186,881909
968,3867746572,2489482975,1182514947,4227629611,702890999,1527651364,2300042744,
3201868674,1824612958,506084749,3425958993,2190268568,1351948612,578700951,40333
16683,3349739825,363935981,1733977918,3041109730,147102666,3671939606,2822112709
,2049950745,1306573411,2683927487,3977389164,1057744304,2463974283,1086620247,84
1997700,3761642584,3623445026,98608126,1997274157,2769436145,412418265,339822208
5,3093798614,1786666762,1571889520,2410209452,4249075583,794459811,2721050302,18
82599266,48066737,3502551405,3876310807,890375883,1207521560,2514522308,67788337
2,4202589232,2291479523,1519186495,1833143365,3210366361,3450933834,531157910,29
94632109,1617409137,311225250,3231001214,4149892100,625186264,1470679563,2242972
631,943077119,3929012003,2563025136,1256024364,2098337622,2936788618,3722479961,
267995269,3284841684,299070728,1664625371,2971790087,2263782781,1425495201,63937
2146,4094020270,1233319814,2610640474,3916458377,996780117,212260399,3737065459,
2891204640,2119010812,3550162887,25357851,1936306632,2708500500,2529103470,11517
82834,911052897,3830731197,1507028117,2345315657,4179751578,725103430,485969212,
3471740128,3154498355,1847333615,3815342834,829440814,1134238973,2441272609,2790
105947,1951687303,113196372,3567713416,1763819936,3141009532,3386073007,46626366
7,738582537,4263256533,2365029894,1592704986,4080540129,555866173,1405781998,217
8106930,3055302728,1678113172,384738887,3304548251,2037406387,2875825007,3649225
916,194708832,1012169498,3998071494,2628183317,1321149641],[0,30977159,61954318,
40498569,123908636,112860827,80997138,84625301,247817272,253610175,225721654,212
636081,161994276,142572195,169250602,198058925,495634544,475161847,507220350,534
986233,451443308,456185579,425272162,411144165,323988552,311886031,285144390,287
726017,338501204,368423635,396117850,373615581,991269088,986528871,950323694,964
453737,1014440700,1034915451,1069972466,1042208629,902886616,872962143,912371158
,934871377,850544324,862644803,822288330,819704653,647977104,659026967,623772062
,620145945,570288780,539313675,575452034,596909829,677002408,696422447,736847270
,708036897,792235700,786440755,747231162,760314685,1982538176,2012450119,1973057
742,1950536777,1900647388,1888567131,1928907474,1931503189,2028881400,2033641855
,2069830902,2055712881,2139944932,2119457635,2084417258,2112160365,1805773232,17
86332471,1745924286,1774722105,1824742316,1830549291,1869742754,1856679461,17010
88648,1690050831,1725289606,1728935937,1644576660,1675531027,1639409306,16179389
73,1295954208,1290149287,1318053934,1331119273,1247544124,1266986939,1240291890,
1211496117,1140577560,1109621151,1078627350,1100095633,1150904068,1161939843,119
3819658,1190171277,1354004816,1366087127,1392844894,1390251225,1473694540,144378
4651,1416073794,1438596805,1584471400,1604956655,1572881510,1545136353,149446232
4,1489699827,1520629370,1534745341,3965076352,3985567495,4024900238,3997152777,3
946115484,3941358875,3901073554,3915187221,3801294776,3813378879,3777134262,3774
534193,3857814948,3827906851,3863006378,3885522989,4057762800,4026804087,4067283
710,4088757881,4139661804,4150695275,4111425762,4107783269,4279889864,4274078543
,4238915270,4251982401,4168834516,4188270931,4224320730,4195526749,3611546464,36
00515047,3572664942,3576309481,3491848572,3522809339,3549444210,3527972085,36494
84632,3630046175,3661098582,3689890513,3739485508,3745294787,3713358922,37002897
41,3402177296,3406935959,3380101662,3365990041,3450579212,3430090123,3457871874,
3485621381,3289153320,3319059375,3351062054,3328543393,3278818612,3266732467,323
5877946,3238475965,2591908416,2611334855,2580298574,2551486409,2636107868,263031
9323,2662238546,2675320277,2495088248,2506140415,2533973878,2530341873,248058378
0,2449610979,2422992234,2444444141,2281155120,2251228855,2219242302,2241748921,2
157254700,2169353387,2200191266,2197613989,2301808136,2297062031,2323879686,2338
012033,2387639316,2408108179,2380342554,2352581021,2708009632,2695912999,2732174
254,2734753577,2785689788,2815618107,2780502450,2757997877,2947389080,2926918175
,2887569302,2915328785,2832147588,2836891651,2877193610,2863059213,3168942800,31
74733399,3209913310,3196833625,3145763020,3126338635,3090272706,3119086917,29889
24648,3019895407,2979399654,2957945697,3041258740,3030204531,3069490682,30731206
37],[0,3698170551,3155831001,1618457198,2096450565,2694370994,3236914396,4783468
59,4192901130,629605053,1173401811,2577214052,2233455631,1500663480,956693718,38
48824417,4145294755,729397012,1259210106,2539888589,2346803622,1468857105,939215
231,3952530376,251573673,3532861214,3001326960,1854474183,1913387436,2925945627,
3457274229,310135746,3941156593,914676806,1458794024,2325673119,2518420212,12489
56483,705045037,4134254746,319020795,3480110156,2937714210,1937009813,1878430462
,3013281865,3555506727,260120720,503147346,3247501797,2716287883,2106251580,1627
924311,3177561568,3708948366,25138489,3826774872,947546607,1477303169,2220900662
,2564996957,1150232042,620271492,4170517811,3507720277,226364130,1829353612,2976
129595,2917588048,1904953063,301790345,3448860222,687409247,4103377640,249791296
6,1217313329,1410090074,2288115437,3893783683,880539188,638041590,4201260865,258
5629999,1181749144,1525871091,2258594628,3874019626,981812125,3756860924,5876922
7,1677135141,3214579602,2736286201,2138436430,520241440,3278887831,1006294692,38
85452307,2279669373,1535993034,1192204961,2606891030,4212503160,662186191,325584
8622,511562777,2114610807,2724723904,3202679467,1653119004,50276978,3734155461,3
438213895,277045680,1895093214,2895726953,2954606338,1819684277,201433051,349674
0204,889479949,3916036538,2300464084,1433653603,1240542984,2510075327,4125820881
,696687974,2800106781,2055972778,452728260,3331428211,3658707224,108981167,17118
88833,3127165814,1594664215,2204188576,3809906126,1065031545,603580690,428791901
3,2682503627,1133403004,1374818494,2376043017,3991418983,830841552,755457211,405
0306572,2434626658,1299246805,2820180148,1953829379,335716461,3362732762,3572352
177,142630406,1761078376,3030021855,1276083180,2422399323,4027929397,746113410,8
21704681,3969363294,2363498288,1351452039,3051742182,1770551633,167758655,358313
6136,3373314019,360527188,1963624250,2842107277,3139130959,1735838968,117538454,
3681346593,3354270282,461603069,2079601299,2811865124,1123143237,2661045490,4276
872860,579238955,1040482880,3798538487,2183047833,1584607278,2012589384,28788797
43,3421472145,394403622,184607053,3614276602,3071986068,1802982179,2384409922,13
83247861,839196059,3999827756,4075452743,780657648,1324372382,2459814697,2162262
251,1552685660,1023125554,3767939717,4229221614,544822873,1074717751,2623766144,
2030770401,2774958678,3306238008,427600527,100553956,3650342483,3118758973,17035
36266,2635918265,1097953550,554091360,4251670999,3790186428,1032076555,157624304
5,2174621138,1693873075,3097225476,3639368554,75612637,402866102,3295585537,2753
107823,2020904408,1778959898,3060096173,3591564995,176125044,385714719,339843908
0,2867307206,1988769905,2481085968,1334822055,804812489,4086688894,4011266581,86
3668386,1393375948,2405474427]] :: [[Word32]]
  x2 := v0
  x1 := (arrLength x2)
  x3 := 0 :: Word32
  x4 := 0 :: Int
  v3 := (tup2 x3 x4)

  for v2 in 0 .. (x1-1) do
    x10 := 3 :: Int
    x11 := 0 :: Int
    x9 := (x10 - x11)
    x12 := 1 :: Int
    x8 := (x9 + x12)
    x7 := (i2n x8)
    x17 := v3
    x16 := (sel1 x17)
    x19 := v0
    x21 := v3
    x20 := (sel2 x21)
    x18 := (getIx x19 x20)
    x15 := (xor x16 x18)
    x14 := (bitSize x15)
    x22 := 8 :: Int
    x13 := (div x14 x22)
    x6 := (min x7 x13)
    v5 := 0 :: Word32

    for v4 in 0 .. (x6-1) do
      x23 := v5
      x26 := v1
      x29 := v4
      x28 := (i2n x29)
      x30 := 0 :: Int
      x27 := (x28 + x30)
      x25 := (getIx x26 x27)
      x37 := v3
      x36 := (sel1 x37)
      x39 := v0
      x41 := v3
      x40 := (sel2 x41)
      x38 := (getIx x39 x40)
      x35 := (xor x36 x38)
      x43 := 8 :: Int
      x50 := v3
      x49 := (sel1 x50)
      x52 := v0
      x54 := v3
      x53 := (sel2 x54)
      x51 := (getIx x52 x53)
      x48 := (xor x49 x51)
      x47 := (bitSize x48)
      x55 := 8 :: Int
      x46 := (div x47 x55)
      x56 := 1 :: Int
      x45 := (x46 - x56)
      x63 := v3
      x62 := (sel1 x63)
      x65 := v0
      x67 := v3
      x66 := (sel2 x67)
      x64 := (getIx x65 x66)
      x61 := (xor x62 x64)
      x60 := (bitSize x61)
      x68 := 8 :: Int
      x59 := (div x60 x68)
      x69 := v4
      x58 := (x59 - x69)
      x70 := 1 :: Int
      x57 := (x58 - x70)
      x44 := (x45 - x57)
      x42 := (x43 * x44)
      x34 := (shiftR x35 x42)
      x71 := 255 :: Word32
      x33 := (x34 .&. x71)
      x32 := (i2n x33)
      x31 := (i2n x32)
      x24 := (getIx x25 x31)
      v5 := (xor x23 x24)
    x5 := v5
    x74 := v3
    x73 := (sel2 x74)
    x75 := 1 :: Int
    x72 := (x73 + x75)
    v3 := (tup2 x5 x72)
  x0 := v3
  out := (sel1 x0)
--}


onCond :: Data Bool -> Data Int -> Data Int
onCond b m = m .&. (- (b2i b))

sumEven1 :: Vector (Data Int) -> Data Int
sumEven1 = sum . map (\i -> onCond (i .&. 1 == 0) i)

swapOE1 :: (Syntax a) => Vector a -> Vector a
swapOE1 v = Indexed (length v) ixf
  where
    ixf i = (i `mod` 2 == 0) ? (index v (i+1), index v (i-1))

-- same as above
swapOE2 :: Vector a -> Vector a
swapOE2 = premap (\i -> (i `mod` 2 == 0) ?  (i+1,i-1))

swapOE3 :: Vector a -> Vector a
swapOE3 = premap (`xor` 1)

premap :: (Data Index -> Data Index) -> Vector a -> Vector a
premap f (Indexed l ixf) = Indexed l (ixf . f)


bitr :: Data Index -> Data Index -> Data Index
bitr n a =
    share (oneBitsN n) $ \mask -> (complement mask .&. a) .|. rev mask
  where
    rev mask = rotateL (reverseBits (mask .&. a)) n

bitRev :: Data Index -> Vector a -> Vector a
bitRev = premap . bitr

countUp :: Data Length -> Vector (Data Index)
countUp n = Indexed n id

pipe :: Syntax a => (Data Index -> a -> a) -> Vector (Data Index) -> a -> a
pipe = flip . fold . flip

specbr m n v = bL2Int (l ++ r')
  where
    iv = int2BLN m v
    (l,r) = splitAt (m-n) iv
    r' = reverse r




{--
checkCRC :: (VecBool -> VecBool -> VecBool) -> VecBool -> VecBool -> Data Bool
checkCRC crc poly msg = fold && true (map not (crc poly (msg ++ (crc poly msg))))
--}