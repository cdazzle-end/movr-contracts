// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

// import "./interfaces/IUniswapV3Pool.sol";
import "./interfaces/IUniswapV3Manager.sol";
import "./interfaces/IAlgebraSwapCallback.sol";
// import '@uniswap/v3-core/contracts/libraries/SafeCast.sol';
// import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import '@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol';
import '@uniswap/v3-periphery/contracts/libraries/CallbackValidation.sol';
import '@uniswap/v3-core/contracts/libraries/SafeCast.sol';
// import '@uniswap/v3-core/contracts/libraries/TickMath.sol';
// import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import '@uniswap/v3-periphery/contracts/base/PeripheryPayments.sol';

import '@uniswap/v3-periphery/contracts/base/PeripheryPaymentsWithFee.sol';
// import '@uniswap/v3-periphery/contracts/libraries/Path.sol';
import '@uniswap/v3-periphery/contracts/libraries/PoolAddress.sol';
// import '@uniswap/v3-periphery/contracts/libraries/Pool.sol';
// import '@uniswap/v3-periphery/contracts/libraries/CallbackValidation.sol';

import "./lib/TickMath.sol";
import "./lib/Path.sol";
import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// using SafeERC20 for IERC20;
// import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

// interface IERC20 {
//     function approve(address spender, uint amount) external returns (bool);
//     function transfer(address recipient, uint amount) external returns (bool);
//     function transferFrom(address sender, address recipient, uint amount) external returns (bool);
//     function allowance(address owner, address spender) external view returns (uint256);
//     function balanceOf(address owner) external view returns (uint256);
// }

// interface IWETH9 is IERC20{
//     function deposit() external payable;
//     function withdraw(uint wad) external;
// }
interface IUniswapPoolV2 {
    // function swap(bytes memory swapCall) external returns (bool);
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes memory data) external;
}
interface IZenlinkPoolV2{
    function swap(uint256 amount0Out, uint256 amount1Out, address to) external;
}

contract DexV3Manager is IUniswapV3Manager, IUniswapV3SwapCallback, IAlgebraSwapCallback, PeripheryPayments {
    event DebugLog(string message, address data);
    event DebugLogInt(string message, int data);

    using Path for bytes;
    
    struct SwapSingleCallbackData{
        address tokenIn;
        address tokenOut;
        address payer;
    }
    struct PoolKey {
        address token0;
        address token1;
        uint24 fee;
    }

    address immutable uniFactoryAddress = 0x28f1158795A3585CaAA3cD6469CD65382b89BB70;
    bytes32 immutable uniInitHash = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;
    address immutable algebraFactoryAddress = 0xaB8C35164a8e3EF302d18DA953923eA31f0Fe393;
    bytes32 immutable algebraInitHash = 0x424896f6cdc5182412012e0779626543e1dc4b12e1c45ee5718ae92f10ad97f2;
    address immutable algebraDeployer = 0x965A857955d868fd98482E9439b1aF297623fb94;
    address immutable solarFactoryAddress = 0x51f9DBEd76f5Dcf209817f641b549aa82F35D23F;
    bytes32 immutable fraxInitHash = hex'46dd19aa7d926c9d41df47574e3c09b978a1572918da0e3da18ad785c1621d48';
    bytes32 immutable stellaInitHash = 0x48a6ca3d52d0d0a6c53a83cc3c8688dd46ea4cb786b169ee959b95ad30f61643 ;
    // address wrapNativeTokenAddress = 0xAcc15dC74880C9944775448304B263D191c6077F;

    // constructor with uni factory address and wrapped glmr address
    constructor() PeripheryImmutableState(0x28f1158795A3585CaAA3cD6469CD65382b89BB70, 0xAcc15dC74880C9944775448304B263D191c6077F) {
        // factory
        // WETH9
    }


    // Swap entry point
    // Will route swap instructions to correct functions, V3 or V2
    // V2 swap params ***
    // address[] memory dexAddresses,
    // uint256[] memory abiIndex,
    // address[] memory inputTokens,
    // address[] memory outputTokens,
    // uint256[] memory amounts0In,
    // uint256[] memory amounts1In,
    // uint256[] memory amounts0Out,
    // uint256[] memory amounts1Out,
    // uint256[] memory movrWrapAmount,
    // bytes[] memory data
    // V3 swap params ***
    // uint256[] memory abiIndex
    // address[] memory dexAddresses,
    // address tokenIn;
    
    // address tokenOut;
    // uint24 fee;
    // uint256 amountIn;
    // uint160 sqrtPriceLimitX96;
    // address poolAddress;

    // Combined swap param object
    // address dexAddress
    // uint24 abiIndex
    // address inputToken
    // uint24 inputTokenIndex
    // address outputToken
    // uint256 amountIn
    // uint256 amountOut
    // uint24 fee

    // OR

    // Seperate sturcts within wrapper
    // ManagerSwapParams


    // struct V2SwapParams{
    //     uint256 amount0In; // May be unnecessary, if using inputTokenIndex
    //     uint256 amount1In;
    //     uint256 amount0Out;
    //     uint256 amount1Out;
    // }

    // struct V3SwapParams{
    //     uint24 fee;
    //     uint256 amountIn;
    //     uint160 sqrtPriceLimitX96;
    // }

    struct ManagerSwapParams {
        uint8 swapType; // 0 for V2, 1 for V3
        address dexAddress;
        uint8 abiIndex;
        uint8 inputTokenIndex;
        address inputToken;
        address outputToken;
        uint256 amountIn;
        uint256 amountOut;
        uint256 glmrWrapAmount; // Maybe unecessary
        uint24 fee; // V3
        uint160 sqrtPriceLimitX96; // V3
        bytes data;
    }

    struct V2SwapParams{
        address poolAddress;
        uint8 abiIndex;

    }

    // MAIN entry point
    // Manager contract will hold all tokens until end. Transfer glmr to contract with function call, or safeTransferFrom the input token from wallet -> contract.
    function executeSwaps(ManagerSwapParams[] calldata swapParams) external payable returns (uint256 amountOut){
        console.log("Executing Swaps");

        uint256 glmrReceived = msg.value;
        console.log("Glmr received: ", glmrReceived);
         

        // 1. If first input token is GLMR, need to wrap. Else safeTransferFrom the token to manager
        if(swapParams[0].inputToken == WETH9){
            console.log("Glmr required: ", swapParams[0].amountIn);
            require(msg.value >= swapParams[0].amountIn, "Caller did not send enough glmr to match input amount"); // Make sure caller sent enough glmr to wrap
            require(address(this).balance >= swapParams[0].amountIn, "Contract doesn't have enough glmr to wrap to match input amount"); // Make sure contract has enough glmr
            wrapGLMR(msg.value);
            require(IWETH9(WETH9).balanceOf(address(this)) >= swapParams[0].amountIn, "After wrappping, WGLMR is less than swap input amount");
        } else {
            console.log("Transferring input token to manager");

            // Check allowance
            uint256 managerAllowance = IERC20(swapParams[0].inputToken).allowance(msg.sender, address(this)); 
            string memory allowanceLog = string(abi.encodePacked("Manager allowance: ", Strings.toString(managerAllowance), " | Input Amount: ", Strings.toString(swapParams[0].amountIn)));
            console.log(allowanceLog);
            require(managerAllowance >= swapParams[0].amountIn, "Manager allowance is insufficient");

            // Transfer input token to contract
            uint256 currentContractBalance = IERC20(swapParams[0].inputToken).balanceOf(address(this));
            pay(swapParams[0].inputToken, msg.sender, address(this), swapParams[0].amountIn);
            uint256 newContractBalance = IERC20(swapParams[0].inputToken).balanceOf(address(this));

            // Confirm tokens received
            uint256 tokensReceived = newContractBalance - currentContractBalance;
            console.log("Received Tokens: ", tokensReceived);
            require(tokensReceived >= swapParams[0].amountIn, "Did not receive enough input token for swap");
        }

        uint256 managerInputTokenBalance = IERC20(swapParams[0].inputToken).balanceOf(address(this));
        require(managerInputTokenBalance >= swapParams[0].amountIn, "Manager contract does not have sufficient input tokens to begin execution");

        // 2.0 Start loop to execute all swaps
        uint256 prevAmountOut = 0; // Variable to track output from previous swap, used as input for next swap
        for(uint8 i = 0; i < swapParams.length; i++){
            uint256 currentInput;
            
            // 2.1 Set input amount to previous output, or user specified amount if first swap
            if(i == 0){
                currentInput = swapParams[0].amountIn; 
            } else {
                currentInput = prevAmountOut;
            }

            // 2.2 Check for v2 or v3
            if(swapParams[i].swapType == 0){ // V2
                console.log("Executing V2 Swap");
                prevAmountOut = swapSingleV2(swapParams[i], currentInput);
                
            } else { // V3
                // Set swap params
                SwapSingleParams memory v3SwapParams = SwapSingleParams({
                    tokenIn: swapParams[i].inputToken,
                    tokenOut: swapParams[i].outputToken,
                    fee: swapParams[i].fee,
                    amountIn: currentInput,
                    sqrtPriceLimitX96: swapParams[i].sqrtPriceLimitX96,
                    poolAddress: swapParams[i].dexAddress
                });

                // Execute Swap
                console.log("Executing V3 Swap");
                
                prevAmountOut = swapSingleV3(v3SwapParams, swapParams[i].abiIndex);

                // Confirm amount out is sufficient ** Only need to check final output
                // require(prevAmountOut > swapParams[i].amountOut, "Output is less than expected amount");
                console.log("Swap successful");
                string memory swapString = string(
                    abi.encodePacked("Token ", 
                    Strings.toHexString(swapParams[i].inputToken), 
                    ": ",
                    Strings.toString(currentInput), 
                    " ---> Token ",
                    Strings.toHexString(swapParams[i].outputToken), 
                    ": ", 
                    Strings.toString(prevAmountOut)
                ));
                console.log(swapString);
                
        
            }
         }

        amountOut = prevAmountOut;

        // 3.0 Confirm output sufficient and transfer to wallet.
        string memory errorString = string(abi.encodePacked("Output amount is not sufficient. Expected Minimum Output: ", Strings.toString(swapParams[swapParams.length - 1].amountOut), " | Actual Output: ", Strings.toString(amountOut)));
        require(amountOut >= swapParams[swapParams.length - 1].amountOut, errorString);

        // TROUBLESHOOTING
        uint256 contractBalance = IERC20(swapParams[swapParams.length - 1].outputToken).balanceOf(address(this));
        require(contractBalance >= amountOut, "Insufficient token balance in manager contract");

        // uint256 allowance = IERC20(swapParams[swapParams.length - 1].outputToken).allowance(address(this), msg.sender);
        // require(allowance >= amountOut, "Insufficient allowance for transfer");

        // 3.1 If final token is glmr, unwrap and send. Else just transfer token.
        if(swapParams[swapParams.length - 1].outputToken == WETH9){
            unwrapWETH9(amountOut, msg.sender);
        } else {
            // sweepToken(swapParams[swapParams.length - 1].outputToken, amountOut, msg.sender);
            // TransferHelper.transferToken(swapParams[swapParams.length - 1].outputToken, amountOut, msg.sender);
            // TransferHelper.safeTransfer(swapParams[swapParams.length - 1].outputToken, msg.sender, amountOut);
            IERC20(swapParams[swapParams.length - 1].outputToken).transfer(msg.sender, amountOut);
            // TransferHelper.safeTransfer(swapParams[swapParams.length - 1].outputToken, sender, amountOut);
        }

    }

    // V2 swap single
    function swapSingleV2(ManagerSwapParams memory params, uint256 currentInput) 
        private
        returns (uint256 amountOut)
    {
        console.log("SWAP SINGLE V2");
        // address pool = getPool(); 
        IERC20 tokenIn = IERC20(params.inputToken);
        IERC20 tokenOut = IERC20(params.outputToken);
        console.log("Created tokens");

        uint256 amount0Out; uint256 amount1Out;
        if(params.inputTokenIndex == 0){
            amount0Out = 0;
            amount1Out = params.amountOut;
        } else {
            amount1Out = 0;
            amount0Out = params.amountOut;
        }
        console.log("Set amout out variables");
        uint256 tokenInBalanceBefore = tokenIn.balanceOf(address(this));
        console.log("Current token in balance: ", tokenInBalanceBefore );
        uint256 tokenOutBalanceBefore = tokenOut.balanceOf(address(this));
        console.log("Current token out balance: ", tokenOutBalanceBefore);

        require(tokenInBalanceBefore >= currentInput, "V2 Swap: Manager contract balance of input token insufficient");

        TransferHelper.safeTransfer(params.inputToken, params.dexAddress, currentInput);
        // require(tokenIn.transferFrom(msg.sender, params.dexAddress, params.amountIn), "Transfer to dex FAILED");
        if(params.abiIndex == 0){ // solar / uni
            console.log("Executing uni v2 ");
            bytes memory emptyBytes;
            IUniswapPoolV2(params.dexAddress).swap(amount0Out, amount1Out, address(this), emptyBytes); // Does not return a value, need to calculate amount out
        } else if (params.abiIndex == 1) { // Zenlink
            console.log("Executing zen swap");
            IZenlinkPoolV2(params.dexAddress).swap(amount0Out, amount1Out, address(this)); // Does not return a value, need to calculate amount out
        } else {
            revert("Incorrect Abi Index for V2 Swap");
        }
        
        console.log("swap executed");
        uint256 tokenInBalanceAfter = tokenIn.balanceOf(address(this));
        uint256 tokenOutBalanceAfter = tokenOut.balanceOf(address(this));
        console.log("Token out balance after: ", tokenOutBalanceAfter);



        uint256 actualAmountIn = tokenInBalanceBefore - tokenInBalanceAfter;
        amountOut = tokenOutBalanceAfter - tokenOutBalanceBefore;

        console.log("Actual Amount In: ", actualAmountIn);
        console.log("Actual Amount Out: ", amountOut);
        console.log("Expected Minimum Amount Out: ", params.amountOut);

        require(amountOut >= params.amountOut, "Amount out is insufficient");
        console.log("Swap Successful");
    }

    // V3 swap single
    function swapSingleV3(SwapSingleParams memory params, uint8 abiIndex)
        public
        returns (uint256 amountOut)
    {
        if(abiIndex == 2){ // Uni
            amountOut = swapUniV3(params);
        } else if(abiIndex == 3) { // Algebra
            amountOut = swapAlgebraV3(params);
        } else {
            string memory errorString = string(abi.encodePacked("V3 ABI index incorrect: ", Strings.toString(abiIndex)));
            revert(errorString);
        }
    }

    function swapUniV3(SwapSingleParams memory params)
        public
        returns (uint256 amountOut)
    {
        console.log("Token In: ", params.tokenIn);
        console.log("Token Out: ", params.tokenOut);

        amountOut = _swap(
            0,
            params.poolAddress,
            int256(params.amountIn),
            address(this),
            params.sqrtPriceLimitX96,
            SwapCallbackData({
                path: abi.encodePacked(
                    params.tokenIn,
                    params.fee,
                    params.tokenOut
                ),
                payer: address(this)
            })
        );
    }

    function swapAlgebraV3(SwapSingleParams memory params)
        public
        returns (uint256 amountOut)
    {
        amountOut = _swap(
            1,
            params.poolAddress,
            int256(params.amountIn),
            address(this), // 
            params.sqrtPriceLimitX96,
            SwapCallbackData({
                path: abi.encodePacked(
                    params.tokenIn,
                    params.fee,
                    params.tokenOut
                ),
                payer: address(this)
            })
        );
    }

    
    function _swap(
        uint8 dexType, // 0 uni 1 algebra
        address poolAddress, // Unecessary, we can calculate the address from the tokens
        int256 amountIn,
        address recipient, // recipient is manager contract. Transfer tokens to wallet at the end
        uint160 sqrtPriceLimitX96,
        SwapCallbackData memory data
    ) internal returns (uint256 amountOut) {
        (address tokenIn, address tokenOut, uint24 tickSpacing) = data
            .path
            .decodeFirstPool();

        bool zeroForOne = tokenIn < tokenOut;

        (address tokenInTest, address tokenOutTest, uint24 tickSpacingTest) = data.path.decodeFirstPool();
        address payer = data.payer;
        address managerAddress = address(this);

        

        // address factoryTest = pool.factory();


        // console.log("factory: ", factoryTest);

        // console.log("TokenInTest: ", tokenInTest);
        // console.log("TokenOutTest: ", tokenOutTest);
        // console.log("TickSpacingTest: ", tickSpacingTest);
        // console.log("Payer Address: ", payer);
        // console.log("Manager Address: ", managerAddress);

        IUniswapV3Pool pool = IUniswapV3Pool(getPool(tokenIn, tokenOut, tickSpacing,dexType));
        // pool.
        // console.log("Created UNI3 pool address");
        // address token0Test = pool.token0();
        // address token1Test = pool.token1();
        // console.log("Token 0: ", token0Test);
        // console.log("Token 1: ", token1Test);

        (int256 amount0, int256 amount1) = pool.swap(
                recipient,
                zeroForOne,
                amountIn,
                sqrtPriceLimitX96 == 0
                    ? (
                        zeroForOne
                            ? TickMath.MIN_SQRT_RATIO + 1
                            : TickMath.MAX_SQRT_RATIO - 1
                    )
                    : sqrtPriceLimitX96,
                abi.encode(data)
            );


        amountOut = uint256(-(zeroForOne ? amount1 : amount0));
    }


    // Wrap glmr for manager contract
    function wrapGLMR(uint256 amount) internal {
        console.log("Wrapping GLMR");

        IWETH9 wglmr = IWETH9(WETH9);

        uint256 wglmrBefore = wglmr.balanceOf(address(this));
        console.log("wglmr balance before: ", wglmrBefore);

        wglmr.deposit{value: amount}();

        uint256 wglmrAfter = wglmr.balanceOf(address(this));
        console.log("wglmr balance after: ", wglmrAfter);

        uint256 finalWrappedAmount = wglmrAfter - wglmrBefore;
        require(finalWrappedAmount >= amount, "Wrap FAILED");
    }

    /// @dev Returns the pool for the given token pair and fee. The pool contract may or may not exist.
    function getPool(
        address tokenA,
        address tokenB,
        uint24 fee,
        uint8 dexType // 0 uni 1 algabra
    ) private view returns (address) {
            
        PoolAddress.PoolKey memory poolKey = PoolAddress.getPoolKey(tokenA, tokenB, fee);
        address poolFactory;
        bytes32 initHash;
        if(dexType == 0){
            console.log("Get UNI Pool address");
            poolFactory = uniFactoryAddress;
            initHash = uniInitHash;
        } else {
            console.log("Get ALGEBRA Pool address");
            // algebra uses deployer contract 
            // poolFactory = algebraFactoryAddress;
            poolFactory = algebraDeployer;
            initHash = algebraInitHash;

        }
        // console.log("pool key token 0: ", poolKey.token0);
        // console.log("pool key token 1: ", poolKey.token1);
        // console.log("pool key fee: ", poolKey.fee);
        // console.log("Deployer: ", poolFactory);
        bytes memory hvalue = hex"ff";
        string memory hint = string(hvalue);
        // console.log("Hex ff value: ", hint);
        // console.logBytes(hvalue);
        // console.log(hvalue);

        // console.log("Init hash");
        // console.logBytes32(initHash);

        bytes memory packedOne;
        if(dexType == 0){
            packedOne = abi.encode(poolKey.token0, poolKey.token1, poolKey.fee);
        } else {
            packedOne = abi.encode(poolKey.token0, poolKey.token1);
        }
        // console.log("Packed One");
        // console.logBytes(packedOne);

        bytes32 poolKeyHash = keccak256(packedOne);
        // console.log("Pool Key Hash");
        // console.logBytes32(poolKeyHash);

        bytes memory packedTwo = abi.encodePacked(hex"ff", poolFactory, poolKeyHash, initHash);
        // console.log("Packed Two");
        // console.logBytes(packedTwo);

        bytes32 poolAddressHash = keccak256(packedTwo);
        // console.log("Pool Address hash");
        // console.logBytes32(poolAddressHash);


        uint256 poolAddressUint256 = uint256(poolAddressHash);
        uint160 poolAddressUint160 = uint160(poolAddressUint256);
        // address poolAddress256String = address(poolAddressUint256);
        address poolAddress160String = address(poolAddressUint160);
        


        // console.log("Pool Address Uint256: ", poolAddressUint256);
        // console.log("Pool Address Uint160: ", poolAddressUint160);
        // console.log("Pool Address: ", poolAddress160String);

        address poolAddressFinal = address(uint160(uint256(poolAddressHash)));

        // address computedAddress = PoolAddress.computeAddress(factory, poolKey);
        // console.log("Computed pool address: ", computedAddress);
        console.log("Pool Address Final: ", poolAddressFinal);

        // return IUniswapV3Pool(PoolAddress.computeAddress(factory, PoolAddress.getPoolKey(tokenA, tokenB, fee)));
        // return IUniswapV3Pool(poolAddressFinal);
        return poolAddressFinal;
    }

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata _data
    ) external override {
        console.log("Received UNI callback from pool");
        require(amount0Delta > 0 || amount1Delta > 0); // swaps entirely within 0-liquidity regions are not supported
        SwapCallbackData memory data = abi.decode(_data, (SwapCallbackData));
        address uni3Factory = 0x28f1158795A3585CaAA3cD6469CD65382b89BB70;
        (address tokenIn, address tokenOut, uint24 fee) = data.path.decodeFirstPool();
        // CallbackValidation.verifyCallback(uni3Factory, tokenIn, tokenOut, fee);

        IERC20 tokenInContract = IERC20(tokenIn);

        (bool isExactInput, uint256 amountToPay) =
            amount0Delta > 0
                ? (tokenIn < tokenOut, uint256(amount0Delta))
                : (tokenOut < tokenIn, uint256(amount1Delta));

        if (isExactInput) {
            pay(tokenIn, data.payer, msg.sender, amountToPay);
        } else {
            // either initiate the next swap or pay
            if (data.path.hasMultiplePools()) {
                data.path = data.path.skipToken();
                // exactOutputInternal(amountToPay, msg.sender, 0, data);
            } else {
                // amountInCached = amountToPay;
                // note that because exact output swaps are executed in reverse order, tokenOut is actually tokenIn
                pay(tokenOut, data.payer, msg.sender, amountToPay);
            }
        }
    }

    function algebraSwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata _data
    ) external override {
        console.log("Received ALGEBRA callback from pool");
        require(amount0Delta > 0 || amount1Delta > 0); // swaps entirely within 0-liquidity regions are not supported
        SwapCallbackData memory data = abi.decode(_data, (SwapCallbackData));
        // address algebraDeployerContract = 0x28f1158795A3585CaAA3cD6469CD65382b89BB70;
        (address tokenIn, address tokenOut, uint24 fee) = data.path.decodeFirstPool();
        // CallbackValidation.verifyCallback(uni3Factory, tokenIn, tokenOut, fee);

        // IERC20 tokenInContract = IERC20(tokenIn);

        console.log("Payer Address: ", data.payer);

        (bool isExactInput, uint256 amountToPay) =
            amount0Delta > 0
                ? (tokenIn < tokenOut, uint256(amount0Delta))
                : (tokenOut < tokenIn, uint256(amount1Delta));

        console.log("Is Exact Input: ", isExactInput);
        if (isExactInput) {
            pay(tokenIn, data.payer, msg.sender, amountToPay);
        } else {
            // either initiate the next swap or pay
            if (data.path.hasMultiplePools()) {
                data.path = data.path.skipToken();
            } else {
                // note that because exact output swaps are executed in reverse order, tokenOut is actually tokenIn
                pay(tokenOut, data.payer, msg.sender, amountToPay);
            }
        }
    }

    // function exactInputInternal(
    //     uint256 amountIn,
    //     address recipient,
    //     uint160 sqrtPriceLimitX96,
    //     SwapCallbackData memory data
    // ) private returns (uint256 amountOut) {
    //       // find and replace recipient addresses
    //     // if (recipient == Constants.MSG_SENDER) recipient = msg.sender;
    //     // else if (recipient == Constants.ADDRESS_THIS) recipient = address(this);

    //     if (recipient == msg.sender) recipient = msg.sender;
    //     else if (recipient == address(this)) recipient = address(this);
    //     (address tokenIn, address tokenOut, uint24 fee) = data.path.decodeFirstPool();

    //     bool zeroForOne = tokenIn < tokenOut;

    //     (int256 amount0, int256 amount1) =
    //         getPool(tokenIn, tokenOut, fee).swap(
    //             recipient,
    //             zeroForOne,
    //             int256(amountIn),
    //             sqrtPriceLimitX96 == 0
    //                 ? (zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1)
    //                 : sqrtPriceLimitX96,
    //             abi.encode(data)
    //         );

    //     return uint256(-(zeroForOne ? amount1 : amount0));
    // }
    // Replace your safeTransfer function with SafeERC20's safeTransfer method
    // function transferToken(address token, address to, uint256 value) internal {
    //     // SafeERC20(token).safeTransfer(to, value);
    //     SafeERC20(token).transfer(token, to, value);
    // }

    function transferToContract(        
        uint256 amountIn,
        address tokenIn
    ) public payable {
        IERC20 tokenContract = IERC20(tokenIn);

        uint256 walletBalance = tokenContract.balanceOf(msg.sender);
        require(walletBalance >= amountIn, "Wallet has insufficient funds");
        require(tokenContract.transferFrom(msg.sender, address(this), amountIn), "Unable to transfer tokens to contract");
    }
}





    // function swap(address poolAddress_, bool zeroForOne, uint256 amountSpecified, uint160 priceLimit, bytes memory data) public {
    //     console.log("Received swap call");
    //     console.log("Initiate SWAP");
    //     console.log("Pool Address ??: ", poolAddress_);
    //     console.log("zeroForOne: ", zeroForOne);
    //     console.log("AmountSpecified: ", amountSpecified);
    //     console.log("Price Limit: ", priceLimit);

    //     IUniswapV3Pool poolContract = IUniswapV3Pool(poolAddress_);


    //     address token0 = poolContract.token0();
    //     address token1 = poolContract.token1();

    //     console.log("Token 0: ", token0);
    //     console.log("Token 1: ", token1);

    //     SwapSingleCallbackData memory callbackData = abi.decode(data, (SwapSingleCallbackData));

    //     // SwapSingleCallbackData memory callbackData = SwapSingleCallbackData(data);

    //     (int256 amount0, int256 amount1) = poolContract.swap(msg.sender, zeroForOne, amountSpecified, priceLimit, abi.encode(callbackData));

    //     console.log("Amount 0: ", Strings.toString(uint256(amount0)));
    //     console.log("Amount 1: ", Strings.toString(uint256(amount1)));

    //     // int256 amount0;
    //     // int256 amount1;
    //     // try IUniswapV3Pool(poolAddress_).swap(msg.sender, zeroForOne, amountSpecified, priceLimit, data)  returns (int256 returnedAmount0, int256 returnedAmount1){
    //     //     amount0 = returnedAmount0;
    //     //     amount1 = returnedAmount1;
    //     //     console.log("Swap call successful");
    //     // } catch Error(string memory reason) {
    //     //     console.log("Withdraw unsuccessful");
    //     //     console.log(reason);
    //     //     revert(reason);
    //     // }
    //     // console.log("END");
    // }

// contract DexV3Manager is IUniswapV3Manager {
//     function mint(
//         address poolAddress_,
//         int24 lowerTick,
//         int24 upperTick,
//         uint128 liquidity,
//         bytes calldata data
//     ) public {
//         IUniswapV3Pool(poolAddress_).mint(
//             msg.sender,
//             lowerTick,
//             upperTick,
//             liquidity,
//             data
//         );
//     }

//     // function swap(SwapParams memory params, bytes calldata data) public {
//     //     IUniswapV3Pool(poolAddress_).swap(msg.sender, data);
//     // }

//     function swap(address poolAddress_, bool zeroForOne, uint256 amountSpecified, uint160 priceLimit, bytes calldata data) public {
//         console.log("Received swap call");
//         console.log("Initiate SWAP");
//         console.log("Pool Address: ", poolAddress_);
//         console.log("zeroForOne: ", zeroForOne);
//         console.log("AmountSpecified: ", amountSpecified);
//         console.log("Price Limit: ", priceLimit);
//         try IUniswapV3Pool(poolAddress_).swap(msg.sender, zeroForOne, amountSpecified, priceLimit, data) {
//             console.log("Swap call successful");
//         } catch Error(string memory reason) {
//             console.log("Withdraw unsuccessful");
//             console.log(reason);
//             revert(reason);
//         }
//         console.log("END");
//     }

//     function uniswapV3MintCallback(
//         uint256 amount0,
//         uint256 amount1,
//         bytes calldata data
//     ) public {
//         IUniswapV3Pool.CallbackData memory extra = abi.decode(
//             data,
//             (IUniswapV3Pool.CallbackData)
//         );

//         IERC20(extra.token0).transferFrom(extra.payer, msg.sender, amount0);
//         IERC20(extra.token1).transferFrom(extra.payer, msg.sender, amount1);
//     }
    
//     function uniswapV3SwapCallback(
//         int256 amount0,
//         int256 amount1,
//         bytes calldata data_
//     ) public {
//         console.log("Recieved callback data");
//         // console.log("Amount 0: ", amount0);
//         // console.log("Amount 1: ", amount1);
//         SwapSingleCallbackData memory data = abi.decode(data_, (SwapSingleCallbackData));
//         // int256 am0 = amount0;
//         // console.log("Amount 0: ", am0);
//         // (address tokenIn, address tokenOut, ) = data.path.decodeFirstPool();
//         // (address tokenIn, address tokenOut, uint256 fee) = abi.decode(data, (address, address, uint256));
//         address tokenIn = data.tokenIn;
//         address tokenOut = data.tokenOut;
//         // address payer = data.payer;

//         bool zeroForOne = tokenIn < tokenOut;

//         int256 amount = zeroForOne ? amount0 : amount1;

//         if (data.payer == address(this)) {
//             IERC20(tokenIn).transfer(msg.sender, uint256(amount));
//         } else {
//             IERC20(tokenIn).transferFrom(
//                 data.payer,
//                 msg.sender,
//                 uint256(amount)
//             );
//         }
//     }
// }
