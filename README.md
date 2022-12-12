# Mean Reversion Trading Algorithm
This Repository contains a working implementation of a mean reversion trading algorithm. It is written in MQL for the MetaTrader 5.
## ATTENTION
Unfortunately, the current implementation should not be used on small accounts. Read the next sections to understand why. If you make a lot of money using this repository/idea, feel free to share some with me :-)
## Algorithm Explanation
Mean reversion algorithms make use of the idea, that the price of a given asset tends to come back to an average price after some time
([https://en.wikipedia.org/wiki/Mean_reversion_(finance)](https://en.wikipedia.org/wiki/Mean_reversion_(finance))).
### Moving Average
The average price can be easily defined with a moving average. This algorithm uses the simple moving average 90 and a Timeframe of 15 minutes. 
### Money/Trade Management
Furthermore it uses a certain strategy to open trades. If the price moves away from the moving average to the upside, it is starting to open Sell/Short positions (Vice Versa it opens Buy/Long position if the price moves to the downside). If one position is already open, the next position must have a given distance to the previous one. This **distance doubles** with each additional position opened. Also, the **Lot Size doubles**, with each additional position opened! This is the reason, why this strategy needs a big initial deposit.
## Backtest
Due to the scaling of position size, the algorithm can produce a very huge deposit load. This is especially true, if the market is trending strongly. In my Backtest I used the DAX index. An initial deposit of 150k was needed to survive the Corona crash. In my opinion, much bigger accounts are necessary, to use this strategy with a feasible risk.
## Conclusion
It can be very simple to program a trading strategy that works. If you have further ideas to improve the algorithm, feel free to fork, implement and share or contact me. Hopefully, lots of people can make a lot of money or learn something about the financial markets :-)