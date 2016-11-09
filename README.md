# zap

A standalone Sites JSP that will take either
a) a specific assetid/assetype,
b) a sql query returning any number of assets (where the query returns columns named "assetid" and "assettype")
and for each asset, discovers:
- any attributes of type asset
- any (un)named associations

For each discovered asset, the process is recursively repeated.

For each asset processed, a certain set of core fields/attributes are displayed.

The final result is rendered as an html table.
