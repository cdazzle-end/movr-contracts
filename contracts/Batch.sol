// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "hardhat/console.sol";

interface IERC20 {
    function approve(address spender, uint amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function balanceOf(address owner) external view returns (uint256);
}


interface IDex {
    // function swap(bytes memory swapCall) external returns (bool);
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes memory data) external;
}
interface ZDex{
    function swap(uint256 amount0Out, uint256 amount1Out, address to) external;
}
interface IWMOVR {
    function allowance(address owner, address spender) external view returns (uint256);
    function deposit() external payable;
    function withdraw(uint wad) external;
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address src, address dest, uint256 amount) external returns (bool);
    function balanceOf(address input) external returns (uint256);
}
contract Batch {
    uint public testData = 100;
    address private _movrContract = 0x98878B06940aE243284CA214f92Bb71a2b032B8A;
    IWMOVR public wmovr = IWMOVR(_movrContract);

    receive() external payable {}

    // Wrap and send movr back to wallet. MAY BE better to just implement logic to swap the wmovr from this contract
    function wrapAndTransferMOVR(address recipient, uint256 amount) internal {
        // Ensure the contract has enough MOVR
        // require(msg.value == amount, "Incorrect MOVR amount");
        console.log("Wrap and transfer");
        // Deposit MOVR to get WMOVR
        wmovr.deposit{value: amount}();

        // Get the WMOVR balance of this contract
        uint256 wmovrBalance = wmovr.balanceOf(address(this));
        console.log("wmovr balance after: ", wmovrBalance);
        require(wmovr.transfer(recipient, wmovrBalance), "Transfer failed");
    }

    // Transfer WMOVR from the user to the contract
    function transferWMOVRToContract(uint256 amount, address owner) internal {
        // IWMOVR wmovr = IWMOVR(_movrContract);
        uint256 wmovrAllowance = wmovr.allowance(owner, address(this));
        console.log("Batch contract approved to spend: ", wmovrAllowance);
        console.log("Trying to spend: ", amount);

        require(wmovrAllowance >= amount, "Allowance not high enough");
        require(wmovr.transferFrom(owner, address(this), amount), "Transfer failed");
    }

    function unwrapAndTransferMOVR(address payable recipient, uint256 amount) internal {
        console.log("Unwrap and transfer");
        uint256 wmovrBalance = wmovr.balanceOf(address(this));
        console.log("Contract WMOVR Balance: ", wmovrBalance);

        require(wmovrBalance >= amount, "Insufficient WMOVR balance for unwrap");

        console.log("Initiating unwrapAndTransferMOVR: wmovr.withdraw(amount)");
        try wmovr.withdraw(amount) {
            console.log("Withdraw Successful");
        } catch Error(string memory reason) {
            console.log("Withdraw unsuccessful");
            console.log(reason);
            revert(reason);
        }

        console.log("Unwrap success. Transfer back to recipient...");
        recipient.transfer(amount);
    }

    function executeSwaps(
        address[] memory dexAddresses,
        uint256[] memory abiIndex,
        address[] memory inputTokens,
        address[] memory outputTokens,
        uint256[] memory amounts0In,
        uint256[] memory amounts1In,
        uint256[] memory amounts0Out,
        uint256[] memory amounts1Out,
        uint256[] memory movrWrapAmount,
        bytes[] memory data
    ) public payable {
        console.log("Executing Swaps");
        uint256 totalWrapAmount = 0;
        for(uint256 i = 0; i < dexAddresses.length; i++){
            totalWrapAmount += movrWrapAmount[i];
        }
        require(totalWrapAmount <= msg.value, "Not enough MOVR sent");

        uint256 finalOutAmount = 0;
        for(uint256 i = 0; i < dexAddresses.length; i++){
            
            console.log("Swap #", i);
            //Wrap movr if reqyured
            if(movrWrapAmount[i] > 0){
                console.log("Wrapping movr");
                // IWMOVR(movrContract).deposit{value: movrWrapAmount[i]}();
                // msg.value -= movrWrapAmount[i];
                uint256 wmovrBalanceInitial = wmovr.balanceOf(msg.sender);
                console.log("wmovr balance initial: ", wmovrBalanceInitial);
                wrapAndTransferMOVR(msg.sender, msg.value);
                uint256 wmovrBalanceAfter = wmovr.balanceOf(msg.sender);
                console.log("wmovr balance after: ", wmovrBalanceAfter);
                uint256 newlyWrappedMovr = wmovrBalanceAfter - wmovrBalanceInitial;
                console.log("Newly wrapped movr: ", newlyWrappedMovr);
                require(newlyWrappedMovr == movrWrapAmount[i], "Wrapped movr amount mismatch");
            }
            IERC20 tokenIn = IERC20(inputTokens[i]);
            IERC20 tokenOut = IERC20(outputTokens[i]);
            uint256 inputAmount = amounts0In[i] == 0 ? amounts1In[i] : amounts0In[i];
            uint256 expectedOutputAmount = amounts0Out[i] == 0 ? amounts1Out[i] : amounts0Out[i];

            uint256 tokenInInitialBalance = tokenIn.balanceOf(address(msg.sender));
            console.log("Token in initial balance: ", tokenInInitialBalance);

            uint256 allowance = tokenIn.allowance(msg.sender, address(this));
            require(allowance >= inputAmount, "Batch contract not approved to spend input token for calling address");

            // console.log("Transferring token from wallet to dex address");
            console.log("Token in: ", inputTokens[i]);
            console.log("Token out: ", outputTokens[i]);
            
            console.log("Allowance: ", allowance);
            console.log("Input amount: ", inputAmount);
            require(tokenIn.transferFrom(msg.sender, dexAddresses[i], inputAmount), "Transfer to dex FAILED");
            // console.log("Approving dex to spend token");
            require(tokenIn.approve(dexAddresses[i], inputAmount), "Token approval FAILED");

            uint256 outputBalanceInitial = tokenOut.balanceOf(address(msg.sender));
            // Swap with solar
            if(abiIndex[i] == 0) {
                console.log("Swapping with solar");
                console.log("Dex Address: ", dexAddresses[i]);
                console.log("amounts0Out: ", amounts0Out[i]);
                console.log( "amounts1Out: ", amounts1Out[i]);
                console.log( "msg sender: ", msg.sender);
                // bytes memory data = "0x";
                try IDex(dexAddresses[i]).swap(amounts0Out[i], amounts1Out[i], msg.sender, data[i]){
                    console.log("Solar Swap executed");
                    uint256 finalBalance = tokenOut.balanceOf(address(msg.sender));
                    uint256 receivedAmount = finalBalance - outputBalanceInitial;
                    finalOutAmount = receivedAmount;
                    console.log("Received Amount: ", receivedAmount);
                    console.log("Token out final balance: ", finalBalance);
                    require(receivedAmount >= expectedOutputAmount, "Received amount is less than expected");
                } catch  Error(string memory reason){
                    console.log(reason);
                    revert(reason);
                }
            // Swap with Zenlink
            } else {
                console.log("Swapping with Zenlink");
                try ZDex(dexAddresses[i]).swap(amounts0Out[i], amounts1Out[i], msg.sender){
                    console.log("Zenlink Swap executed");
                    uint256 finalBalance = tokenOut.balanceOf(address(msg.sender));
                    uint256 receivedAmount = finalBalance - outputBalanceInitial;
                    finalOutAmount = receivedAmount;
                    console.log("Received Amount: ", receivedAmount);
                    console.log("Token out final balance: ", finalBalance);
                    require(receivedAmount >= expectedOutputAmount, "Received amount is less than expected");
                } catch  Error(string memory reason){
                    console.log(reason);
                    revert(reason);
                }
            }
            console.log("-------------------------------------");

            if(i == dexAddresses.length - 1 && outputTokens[i] == _movrContract){
                console.log("Need to unwrap...");
                console.log("Transferring WMOVR: ", finalOutAmount);
                transferWMOVRToContract(finalOutAmount, msg.sender);
                console.log("SUCCESS: Transferred WMOVR to batch contract");
                address payable recipient = payable(msg.sender); // Convert msg.sender to a payable address
                console.log("Executing unwrapAndTransferMOVR function");
                unwrapAndTransferMOVR(recipient, finalOutAmount);
            }
        }
    }

    function testCall() public pure {
        console.log("TEST");
    }
    // function transferToken(address token, address to, uint256 amount) public {
    //     IERC20(token).transferFrom(msg.sender, to, amount);
    // }
    
    // function getAllowance(address token, address owner) public view returns (uint256) {
    //     return IERC20(token).allowance(owner, address(this));
    // }

    // Function to batch transfer tokens
    function transferAndSwapHigh(
        address inputToken,
        address outputToken,
        address dex, 
        uint256 amountIn, 
        uint256 expectedAmount,
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes memory data
    ) public {
        console.log("EXECUTING BATCH");
        console.log(dex);
        IERC20 tokenIn = IERC20(inputToken);
        IERC20 tokenOut = IERC20(outputToken);
        uint256 allowance = tokenIn.allowance(msg.sender, address(this));
        require(allowance >= amountIn, "Batch contract not approved to use tokens");
        require(tokenIn.transferFrom(msg.sender, dex, amountIn), "Transfer to DEX failed");
        // console.log("SUCCESS: TRANSFER TOKEN");
        require(tokenIn.approve(dex, amountIn), "Approval failed");
        // console.log("SUCCESS: TOKEN APPROVED");

        uint256 initialBalance = tokenOut.balanceOf(address(msg.sender));
        // console.log("Token Out Initial: ", initialBalance);
        try IDex(dex).swap(amount0Out, amount1Out, to, data) {
            // console.log("Swap success");
            
            uint256 finalBalance = tokenOut.balanceOf(address(msg.sender));
            // console.log("Token Out Final: ", finalBalance);

            uint256 receivedAmount = finalBalance - initialBalance;
            // console.log("Received Amount: ", receivedAmount);

             require(receivedAmount >= expectedAmount, "Received amount is less than expected");
        } catch  Error(string memory reason){
            console.log(reason);
            revert(reason);
        }
    }



        // Function to batch transfer tokens
    function zenlinkTransferAndSwap(
        address inputToken,
        address outputToken,
        address dex, 
        uint256 amountIn, 
        uint256 expectedAmount,
        uint256 amount0Out,
        uint256 amount1Out,
        address to
        // uint256 amount0In,
        // uint256 amount1In,
        // uint256 reserve0,
        // uint256 reserve1
    ) public {
        IERC20 tokenIn = IERC20(inputToken);
        IERC20 tokenOut = IERC20(outputToken);
        uint256 allowance = tokenIn.allowance(msg.sender, address(this));
        require(allowance >= amountIn, "Batch contract not approved to use tokens");
        require(tokenIn.transferFrom(msg.sender, dex, amountIn), "Transfer to DEX failed");
        require(tokenIn.approve(dex, amountIn), "Approval failed");

        // K CALCULATIONS
        // uint256 balance0After = reserve0 + amount0In;
        // uint256 balance1After = reserve1 + amount1In;
        // uint256 balance0Adjusted = balance0After * 1000 - (amount0In * 3);
        // uint256 balance1Adjusted = balance1After * 1000 - (amount1In * 3);
        // uint256 k1 = balance0Adjusted * balance1Adjusted;
        // uint256 k2 = reserve0 * reserve1 * 1000**2;
        // console.log("K1: ", k1);
        // console.log("K2: ", k2);
        // if(k1 >= k2){
        //     console.log("K PASSES");
        // } else {
        //     console.log("K FAILS");
        // }

        uint256 initialBalance = tokenOut.balanceOf(address(msg.sender));
        // console.log("Token Out Initial: ", initialBalance);
        try ZDex(dex).swap(amount0Out, amount1Out, to) {
            // console.log("Swap success");
            
            uint256 finalBalance = tokenOut.balanceOf(address(msg.sender));
            // console.log("Token Out Final: ", finalBalance);

            uint256 receivedAmount = finalBalance - initialBalance;
            // console.log("Received Amount: ", receivedAmount);

             require(receivedAmount >= expectedAmount, "Received amount is less than expected");
        } catch  Error(string memory reason){
            console.log(reason);
            revert(reason);
        }
    }

        // this low-level function should be called from a contract which performs important safety checks
    // function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external lock {
    //     require(amount0Out > 0 || amount1Out > 0, 'SolarBeam: INSUFFICIENT_OUTPUT_AMOUNT');
    //     SwapVariables memory vars = SwapVariables(0, 0, 0, 0, 0, 0, 0);
    //     (vars._reserve0, vars._reserve1,) = getReserves(); // gas savings
    //     require(amount0Out < vars._reserve0 && amount1Out < vars._reserve1, 'SolarBeam: INSUFFICIENT_LIQUIDITY');

    //     vars.fee = 25;

    //     { // scope for _token{0,1}, avoids stack too deep errors
    //         address _token0 = token0;
    //         address _token1 = token1;
    //         require(to != _token0 && to != _token1, 'SolarBeam: INVALID_TO');
    //         if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out); // optimistically transfer tokens
    //         if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out); // optimistically transfer tokens
    //         if (data.length > 0) ISolarCallee(to).uniswapV2Call(_msgSender(), amount0Out, amount1Out, data);
    //         vars.balance0 = IERC20Solar(_token0).balanceOf(address(this));
    //         vars.balance1 = IERC20Solar(_token1).balanceOf(address(this));
    //     }
    //     vars.amount0In = vars.balance0 > vars._reserve0 - amount0Out ? vars.balance0 - (vars._reserve0 - amount0Out) : 0;
    //     vars.amount1In = vars.balance1 > vars._reserve1 - amount1Out ? vars.balance1 - (vars._reserve1 - amount1Out) : 0;
    //     require(vars.amount0In > 0 || vars.amount1In > 0, 'SolarBeam: INSUFFICIENT_INPUT_AMOUNT');
    //     { // scope for reserve{0,1}Adjusted, avoids stack too deep errors
    //         uint balance0Adjusted = vars.balance0.mul(10000).sub(vars.amount0In.mul(vars.fee));
    //         uint balance1Adjusted = vars.balance1.mul(10000).sub(vars.amount1In.mul(vars.fee));
    //         require(balance0Adjusted.mul(balance1Adjusted) >= uint(vars._reserve0).mul(vars._reserve1).mul(10000**2), 'SolarBeam: K');
    //     }

    //     _update(vars.balance0, vars.balance1, vars._reserve0, vars._reserve1);
    //     emit Swap(_msgSender(), vars.amount0In, vars.amount1In, amount0Out, amount1Out, to);
    // }

    // function swap(
    //     uint256 amount0Out,
    //     uint256 amount1Out,
    //     address to
    // ) external override lock {
    //     require(amount0Out > 0 || amount1Out > 0, "INSUFFICIENT_OUTPUT_AMOUNT");
    //     (uint112 _reserve0, uint112 _reserve1) = getReserves();
    //     require(
    //         amount0Out < _reserve0 && amount1Out < _reserve1,
    //         "INSUFFICIENT_LIQUIDITY"
    //     );

    //     uint256 balance0;
    //     uint256 balance1;
    //     {
    //         address _token0 = token0;
    //         address _token1 = token1;
    //         require(to != _token0 && to != _token1, "INVALID_TO");
    //         if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out);
    //         if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out);
    //         balance0 = IERC20(_token0).balanceOf(address(this));
    //         balance1 = IERC20(_token1).balanceOf(address(this));
    //     }
    //     uint256 amount0In = balance0 > _reserve0 - amount0Out
    //         ? balance0 - (_reserve0 - amount0Out)
    //         : 0;
    //     uint256 amount1In = balance1 > _reserve1 - amount1Out
    //         ? balance1 - (_reserve1 - amount1Out)
    //         : 0;
    //     require(amount0In > 0 || amount1In > 0, " INSUFFICIENT_INPUT_AMOUNT");
    //     {
    //         uint256 balance0Adjusted = balance0.mul(1000).sub(amount0In.mul(3));
    //         uint256 balance1Adjusted = balance1.mul(1000).sub(amount1In.mul(3));
    //         require(
    //             balance0Adjusted.mul(balance1Adjusted) >=
    //                 uint256(_reserve0).mul(_reserve1).mul(1000**2),
    //             "Pair: K"
    //         );
    //     }

    //     _update(balance0, balance1);
    //     emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    // }


    // function transferAndSwap(
    //     address inputToken,
    //     address outputToken,
    //     address dex, 
    //     uint256 amountIn, 
    //     bytes memory swapCall,
    //     uint256 expectedAmount,
    //     uint256 amount0Out,
    //     uint256 amount1Out,
    //     address to,
    //     bytes memory data
    // ) public {

    //     IERC20 tokenIn = IERC20(inputToken);
    //     IERC20 tokenOut = IERC20(outputToken);

    //     require(tokenIn.transferFrom(msg.sender, dex, amountIn), "Transfer to DEX failed");

    //     require(tokenIn.approve(dex, amountIn), "Approval failed");

    //     uint256 initialBalance = tokenOut.balanceOf(address(msg.sender));
    //     console.log("Token Out Initial: ", initialBalance);
    //     try IDex(dex).swap(amount0Out, amount1Out, to, data) {
    //         console.log("Swap success");
            
    //         uint256 finalBalance = tokenOut.balanceOf(address(msg.sender));
    //         console.log("Token Out Final: ", finalBalance);

    //         uint256 receivedAmount = finalBalance - initialBalance;
    //         console.log("Received Amount: ", receivedAmount);

    //          require(receivedAmount >= expectedAmount, "Received amount is less than expected");
    //     } catch  Error(string memory reason){
    //         console.log(reason);
    //         revert(reason);
    //     }

    //     // (bool success, ) = dex.call(swapCall);
    //     // require(success, "Swap failed");

        
       
    // }

    //     function batchTransfer(address[] memory tokens, address[] memory to, uint256[] memory amounts) public {
    //     require(tokens.length == to.length && to.length == amounts.length, "Input arrays must have the same length");

    //     for (uint i = 0; i < tokens.length; i++) {
    //         IERC20 token = IERC20(tokens[i]);
    //         require(token.transferFrom(msg.sender, to[i], amounts[i]), "Transfer failed");
    //     }
    // }

    // // Function to batch execute swaps on different DEXes
    // function batchSwap(address[] memory dexes, bytes[] memory calls) public {
    //     require(dexes.length == calls.length, "Dexes and calls arrays must have the same length");

    //     for (uint i = 0; i < dexes.length; i++) {
    //         (bool success, ) = dexes[i].call(calls[i]);
    //         require(success, "Swap failed");
    //     }
    // }

    //     // Error handling and security checks should be implemented as needed

    // // Function to batch transfer to a DEX and then execute a swap
    // function batchTransferAndSwap(
    //     address[] memory tokens, 
    //     address[] memory dexes, 
    //     uint256[] memory amounts, 
    //     bytes[] memory swapCalls
    // ) public {
    //     require(tokens.length == dexes.length && dexes.length == amounts.length && amounts.length == swapCalls.length, "Arrays must have the same length");

    //     for (uint i = 0; i < tokens.length; i++) {
    //         IERC20 token = IERC20(tokens[i]);

    //         // Transfer tokens to the DEX
    //         require(token.transferFrom(msg.sender, dexes[i], amounts[i]), "Transfer to DEX failed");

    //         // Approve the DEX to spend the tokens if necessary
    //         require(token.approve(dexes[i], amounts[i]), "Approval failed");

    //         // Execute the swap on the DEX
    //         (bool success, ) = dexes[i].call(swapCalls[i]);
    //         require(success, "Swap failed");
    //     }
    // }

    // Additional functions and error handling as required
}
