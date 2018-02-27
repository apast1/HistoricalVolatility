_This is a copy of the issue submitted to the [HistoricalVolatility repository](https://github.com/TommasoBelluzzo/HistoricalVolatility). 
The document explains the discrepancy found between the Yang-Zhang volatility calculations as implemented in the R TTR package and that implemented by the `estimate_volatility` function in the original HistoricalVolatility repository._

-----

I was testing your implementation of Yang-Zhang volatility against the [TTR implementation](https://github.com/joshuaulrich/TTR) and found a discrepancy between the two outputs. For test data, I used daily SPY OHLC data from 2015-11-25 to 2015-12-11. The results of the TTR and HistoricalVolatility implementation are included below.

HistoricalVolatility:
```
estimate_volatility(SPY,'YZ',10);
>>
    0.1541
    0.1749
```

TTR:
``` 
yz_vol <- TTR::volatility(SPY, N = 252, calc = "yang.zhang")
yz_vol[11:12]

> 
[1] 0.1455561 0.1603981
```

For the following I'm using the notation and reference equations for Yang-Zhang volatility included in the TTR reference documents here: 
https://www.rdocumentation.org/packages/TTR/versions/0.23-3/topics/volatility

The calculations in your `estimate_volatility` function diverge from the reference equations in two places. Yang-Zhang volatility is the weighted composition of three variance components:

`sigma_rs = sigma_o^2 + k*sigma_c^2 + (1-k)*sigma_rs^2.`

The three vectors used to calculate each variance component occurs on line 116: 
```
res = [(log(data.Open ./ [NaN; data.Close(1:end-1)]) .^ 2) (data.Return .^ 2) ((ho .* (ho - co)) + (lo .* (lo - co)))];
```
The values `(data.Return.^2)` corresponds to the values used to calculate`sigma_c^2`. The Yang-Zhang volatility functions in the TTR documentation, however, use the log Close/Open instead of returns. Specifically, 

`sigma_c^2 = N/(n-1) * sum( log( C_i/O_i - mu_c )^2)`

where `C_i` is the closing price and `O_i` is the opening price.

The other discrepancy from the reference equations occurs at line 118 of `estimate_volatility`: 
```
param1 = sqrt(252 / (bw - 1));
```
Here `bw` corresponds to bandwidth or the size of the rolling window used to compute volatility and 252 is the number of active trading days. 

The parameter `param1` is used in the summary function `@fun` to compute each variance component used in the Yang-Zhang formula: `sigma_o^2`, `sigma_c^2`, `sigma_{rs}^2`.  However, the Roger-Satchell formula uses `1/n` not `1/(n-1)`. The value `n` corresponds to the bandwidth parameter,`bw`, in `estimate_volatility` function. 

I forked this repository and updated the code to match the TTR reference equations. These changes are located at lines 125-198 in my version of the _estimate_volatility.m_ file. The output of the updated `estimate_volatility` function now matches the `TTR::volatility()` output. 

```
estimate_volatility(SPY,'YZ',10);
yz_vol =
>>
    0.1456
    0.1604
```

I just wanted to let you know about the discrepancy and open the issue as a reference in case anyone else might find it useful. My fork of the repository with the changes described above is [located here](https://github.com/nateaff/HistoricalVolatility).
