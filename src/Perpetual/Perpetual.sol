// // Contract that allows perpetual trading on weth and wbtc with eNRS as the token collateral


// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "lib/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

// contract PerpetualContract {
//   IERC20 public wbtc;
//   IERC20 public weth;
//   IERC20 public stablecoin;

//   mapping(address => uint256) public balances;
//   mapping(address => uint256) public positionSizes;
//   mapping(address => uint256) public positionCollaterals;

//   uint256 public totalLiquidity;
//   uint256 public maxUtilizationPercentage = 30; 

//   constructor(
//       address _wbtc,
//       address _weth,
//       address _stablecoin
//   ) {
//       wbtc = IERC20(_wbtc);
//       weth = IERC20(_weth);
//       stablecoin = IERC20(_stablecoin);
//   }

//   function deposit(uint256 _amount) external {
//       require(stablecoin.transferFrom(msg.sender, address(this), _amount), "Transfer failed");
//       balances[msg.sender] += _amount;
//       totalLiquidity += _amount;
//   }

//   function withdraw(uint256 _amount) external {
//       require(balances[msg.sender] >= _amount, "Not enough balance");
//       require(totalLiquidity - _amount >= positionSizes[msg.sender], "Cannot withdraw liquidity reserved for positions");
//       require(stablecoin.transfer(msg.sender, _amount), "Transfer failed");
//       balances[msg.sender] -= _amount;
//       totalLiquidity -= _amount;
//   }

//   function openPosition(uint256 size, uint256 collateral) external {
//       require(collateral >= size, "Insufficient collateral");
//       require((size / collateral) <= maxUtilizationPercentage, "Exceeds maximum utilization percentage");
//       require(stablecoin.transferFrom(msg.sender, address(this), collateral), "Transfer failed");
//       positionSizes[msg.sender] += size;
//       positionCollaterals[msg.sender] += collateral;
//   }

//   function increasePositionSize(uint256 additionalSize, uint256 additionalCollateral) external {
//       require(additionalCollateral >= additionalSize, "Insufficient collateral");
//       require((additionalSize / additionalCollateral) <= maxUtilizationPercentage, "Exceeds maximum utilization percentage");
//       require(stablecoin.transferFrom(msg.sender, address(this), additionalCollateral), "Transfer failed");
//       positionSizes[msg.sender] += additionalSize;
//       positionCollaterals[msg.sender] += additionalCollateral;
//   }

//   function increasePositionCollateral(uint256 additionalCollateral) external {
//       require(stablecoin.transferFrom(msg.sender, address(this), additionalCollateral), "Transfer failed");
//       positionCollaterals[msg.sender] += additionalCollateral;
//   }

// function getPrice(address tokenIn, address tokenOut) public view returns (uint256) {
//    uint256 reserveIn = tokenIn == wbtc ? reserveWBTC : reserveWETH;
//    uint256 reserveOut = tokenOut == wbtc ? reserveWBTC : reserveWETH;
//    return reserveOut/reserveIn;
// }

// }
