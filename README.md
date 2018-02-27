# Historical Volatility

This fork of the HistoricalVolatility repository. This fork updates the Yang-Zhang volatility estimator in the `estimate_volatility` function. The changes made to the function were: 
1. Updated the calculation of the `sigma_c^2` volatility component to use Open/Close data rather than returns.
2. Updated the calculation of Roger-Satchel volatility component to use use an average calculated with 1/n rather than 1/(n-1). 

These two corrections match the reference equations in the [TTR documentation](https://github.com/TommasoBelluzzo/HistoricalVolatility), which follow the equations in the original Yang-Zhang paper. 

Tests on a sample dataset show the results of the updated function match that of the TTR output of the `volatility` function for Yang-Zhang volatility. 

The original description of the repository is below.

--------

# About 
The functions in the repository can calculate and analyse the following historical volatility estimators:
* the traditional Close-to-Close estimator and a variant that uses demeaned returns;
* the Parkinson estimator (1980);
* the Garman-Klass estimator (1980) and a variant proposed by Yang & Zhang (2000);
* the Rogers-Satchell estimator (1991);
* the Hodges-Tompkins estimator (2002);
* the Yang-Zhang estimator (2000);
* the Meilijson estimator (2009).

## Contributions

If you want to start a discussion about the project, just open an issue.
Contributions are more than welcome, fork and create pull requests as needed.
