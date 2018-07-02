Install the MetaMask
-------------------------------

1. Install the [Google Chrome Browser](https://www.google.com.tw/chrome/index.html).
2. Install the [MetaMask extension](https://chrome.google.com/webstore/detail/metamask/nkbihfbeogaeaoehlefnkodbefgpgknn).

Install Remix(Compiler of solidity)
-------------------------------
1. Install the [node.js 8.11.3](https://nodejs.org/en/). 
2. Install the [Python 2.7.51](https://www.python.org/downloads/release/python-2715/) and to path.
3. Open the cmd.
4. Install the remixd by entering `npm install -g remixd`.
5. Install the remix by entering `npm install -g remix-ide`.

Opening the MetaMask 
-------------------------------
1. Click the button on the left-top panel.
2. Select the Rinkeby Test Network.
3. Type the password to create the first wallet address.
4. Get the ether from Rinkeby Faucet.

[Tutorial Link](http://zhaozhiming.github.io/blog/2018/04/18/how-to-earn-eth-and-token-in-rinkeby/)

Install the git for windows.
-------------------------------
1. Install [git for windows](https://backlog.com/git-tutorial/tw/intro/intro2_1.html).

Compile with Remix
-------------------------------
1. Download the code from github. `git clone --recursive https://github.com/YSYouJack/MBASmartContract.git`.
2. Open the cmd and entering the downloaded folder using `cd`.
3. Open the remix-ide by entering `remix-ide` in cmd. Now the remix and remixd should be running.
4. Open brower and connect to https://localhost:8080.
5. [Connect to local file server](https://remix.readthedocs.io/en/latest/tutorial_remixd_filesystem.html) and all files will under the *local* folder. 
6. Select the smart contract and click *Start to compiler* button.
7. Deploy the smart contract on *Run* tap and make sure the 'Account' is as same as the account created in MetaMask.
8. Choose the *MBACC* to depoly. 

[Remix Doc](https://remix.readthedocs.io/en/latest/index.html)