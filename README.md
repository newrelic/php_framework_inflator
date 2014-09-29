php_framework_inflator
======================

This repository contains minimal bash scripts used to standup and
"inflate" with real data  a handful of PHP frameworks for testing
and benchmarking.

The frameworks include laravel (4.0 and 4.1) and magento (1.6, 1.7 and 1.8).

Read the specific script to see what flags it takes.

The general approach is to:
  * download the frameworks from their respective distributions,
    perhaps using (modified) composer files;
  * modify the frameworks' source code configuration
    as needed to make a simple generic installation;
  * download canonical sample data either from the vendor or the community,
    typically in the form of a SQL data base dump;
  * reload the SQL data base with the sample data.

These scripts were put together by somebody with a basic passing
familiarity of the laravel and magento installation model. These scripts
been known to work at least once with hhvm and with classic php5,
but may make assumptions about file system paths that are not warranted
on your system.

As of September 2014, there is no canonical sample data base for magento 2.0

Contributing
============

You are welcome to send pull requests to us - however, by doing so you
agree that you are granting New Relic a non-exclusive, non-revokable,
no-cost license to use the code, algorithms, patents, and ideas in
that code in our products if we so choose. You also agree the code
is provided as-is and you provide no warranties as to its fitness or
correctness for any purpose.

