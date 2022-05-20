// SPDX-License-Identifier: MIT

pragma solidity >=0.8.9 <0.9.0;

import 'erc721a/contracts/ERC721A.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/cryptography/MerkleProof.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';

contract NEWDAPES1 is ERC721A, Ownable, ReentrancyGuard {

  using Strings for uint256;


  bytes32 public merkleRoot;

  
  mapping(address => bool) public wlClaimed;
  mapping(address => uint256) internal NFTRewards;

  string internal uriPrefix;
  string internal uriSuffix = '.json';
  string internal hiddenMetadataUri;

  string[] public NFTURIs;

  uint256 internal initialMint = 5;
  uint256 internal hidden_num = 12345;
  uint256 internal uriDevisor = 10;
  uint256 public cost = 0.1 ether;
  uint256 public wlcost = 0.09 ether;
  uint256 public presaleCost = 0.08 ether;
  uint256 public maxSupply = 50;
  uint256 public maxMintAmountPerTx = 3;

  /*convert this to fixed size array
  uint256[3] public rewards = [1,2,3];
  */
  uint256 public RewardAt25 = 2;
  uint256 public RewardAt250 = 5;
  uint256 public RewardAt1000 = 10;
  uint256 public NFTReserve = 5;
  uint256 public ContractState = 0;
  mapping(uint8 => uint256) public rewardMintCounts;
  /*
  uint256 public rewardMintCount25 = 0;
  uint256 public rewardMintCount250 = 0;
  uint256 public rewardMintCount1000 = 0;
  */

  bool public mintRewardsEnabled = true;

  event eventRewardAt25Mint(uint256 indexed _NFTID);
  event eventRewardAt250Mint(uint256 indexed _NFTID);
  event eventRewardAt1000Mint(uint256 indexed _NFTID);

  constructor(
    string memory _tokenName,
    string memory _tokenSymbol,
    string memory _hiddenMetadataUri
  ) ERC721A(_tokenName, _tokenSymbol) {
    uint256 i;
    uint256 x = (maxSupply/uriDevisor) + 1;
    for (i = 0; i < x; i++) {
      NFTURIs.push("");
    }
    setHiddenMetadataUri(_hiddenMetadataUri);
    _safeMint(_msgSender(), initialMint);
  }

  // 0 = paused
  // 1 = Pre sale
  // 2 = whitelist Sale
  // 3 = Public Sale

  modifier mintCompliance(uint256 _mintAmount, uint256 _contractState) {
    require(_contractState != 0, 'Contract is paused!');
    require(_contractState == ContractState, 'Invalid mint type!');
    require(_mintAmount != 0 && _mintAmount <= maxMintAmountPerTx, 'Invalid mint amount!');
    require(totalSupply() + _mintAmount + NFTReserve <= maxSupply, 'Max supply exceeded!');
    _;
  }

  modifier mintCountCompliance(uint256 _mintAmount) {
    require(_mintAmount != 0 && _mintAmount <= maxMintAmountPerTx, 'Invalid mint amount!');
    require(totalSupply() + _mintAmount + NFTReserve <= maxSupply, 'Max supply exceeded!');
    _;
  }

  modifier mintPriceCompliance(uint256 _mintAmount, uint256 _contractState) {
    if (_contractState == 1) {
      require(msg.value >= presaleCost * _mintAmount, 'Funds!');
    } else if (_contractState == 2) {
      require(msg.value >= wlcost * _mintAmount, 'Funds!');
    } else {
      require(msg.value >= cost * _mintAmount, 'Funds!');
    }
    _;
  }

  function randomNum(uint256 _mod, uint256 _rand) internal view returns (uint256) {
    uint256 num = (uint256(keccak256(abi.encode(hidden_num, _rand, msg.sender, _mod + 1))) % _mod) + 1;
    if (num <= initialMint) {
      num = totalSupply();
    }
    return num;
  }

  function distributeReward(uint256 _mintAmount) internal {
      ///load storage mapping values into memory locations,similarly for rewardAt array
      uint rewardMintCount25 = rewardMintCounts[0];
      uint rewardMintCount250 = rewardMintCounts[1];
      uint rewardMintCount1000 = rewardMintCounts[2];
    if (mintRewardsEnabled == true) {
      uint256 supply;
      uint256 num;
      address rewardAdd;

      if ((rewardMintCount25 + _mintAmount >= 25) || (rewardMintCount250 + _mintAmount >= 250) || (rewardMintCount1000 + _mintAmount >= 1000)) {
        supply = totalSupply();
        hidden_num = uint256(keccak256(abi.encode(hidden_num, msg.sender)));
        num = randomNum(supply, hidden_num);      
      }

      if (rewardMintCount25 + _mintAmount >= 25) {
        rewardMintCounts[0] = rewardMintCount25 + _mintAmount - 25;
        hidden_num = uint256(keccak256(abi.encode(hidden_num, msg.sender)));
        num = randomNum(supply, num) + 1;
          if (num <= supply) {
            rewardAdd = ownerOf(num);
            NFTRewards[rewardAdd] = NFTRewards[rewardAdd] + RewardAt25;
            emit eventRewardAt25Mint(num);
          }
      } else {
        rewardMintCounts[0] = rewardMintCount25 + _mintAmount;
      }

      if (rewardMintCount250 + _mintAmount >= 250) {
        rewardMintCounts[1] = rewardMintCount250 + _mintAmount - 250;
        hidden_num = uint256(keccak256(abi.encode(hidden_num, msg.sender)));
        num = randomNum(supply, num) + 1;
          if (num <= supply) {
            rewardAdd = ownerOf(num);
            NFTRewards[rewardAdd] = NFTRewards[rewardAdd] + RewardAt250;
            emit eventRewardAt250Mint(num);
          }
      } else {
        rewardMintCounts[1] = rewardMintCount250 + _mintAmount;
      }

      if (rewardMintCount1000 + _mintAmount >= 1000) {
        rewardMintCounts[2] = rewardMintCount1000 + _mintAmount - 1000;
        hidden_num = uint256(keccak256(abi.encode(hidden_num, msg.sender)));
        num = randomNum(supply, num) + 1;
          if (num <= supply) {
            rewardAdd = ownerOf(num);
            NFTRewards[rewardAdd] = NFTRewards[rewardAdd] + RewardAt1000;
            emit eventRewardAt1000Mint(num);
          }
      } else {
        rewardMintCounts[2] = rewardMintCount1000 + _mintAmount;
      }
    }
  }


  function whitelistMint(uint256 _mintAmount, bytes32[] calldata _merkleProof) public payable mintCompliance(_mintAmount, 2) mintPriceCompliance(_mintAmount, 2)  {
    // Verify whitelist requirements
    require(!wlClaimed[_msgSender()], 'Address already claimed!');
    bytes32 leaf = keccak256(abi.encodePacked(_msgSender()));
    require(MerkleProof.verify(_merkleProof, merkleRoot, leaf), 'Invalid proof!');
    wlClaimed[_msgSender()] = true;
    _safeMint(_msgSender(), _mintAmount);
    distributeReward(_mintAmount);
  }

  function presaleMint(uint256 _mintAmount) public payable mintCompliance(_mintAmount, 1) mintPriceCompliance(_mintAmount, 1) {
    _safeMint(_msgSender(), _mintAmount);
    distributeReward(_mintAmount);
  }


  function mint(uint256 _mintAmount) public payable mintCompliance(_mintAmount, 3) mintPriceCompliance(_mintAmount, 3) {
    _safeMint(_msgSender(), _mintAmount);
    distributeReward(_mintAmount);
  }
  

  function mintRewardNFTs(uint256 _mintAmount) public payable mintCompliance(_mintAmount, 3) {
    // Verify reward requirements
    require(NFTRewards[_msgSender()] >= _mintAmount, 'Mint amount more than available reward!');
    NFTRewards[_msgSender()] = NFTRewards[_msgSender()] - _mintAmount;
    NFTReserve = NFTReserve - _mintAmount;
    _safeMint(_msgSender(), _mintAmount);
  }

  function investorMint(uint256 _mintAmount) public payable mintCountCompliance(_mintAmount) {
    require(NFTRewards[_msgSender()] >= _mintAmount, 'Mint amount more than allocated!');
    NFTRewards[_msgSender()] = NFTRewards[_msgSender()] - _mintAmount;
    NFTReserve = NFTReserve - _mintAmount;
    _safeMint(_msgSender(), _mintAmount);
  }


  function mintForAddress(uint256 _mintAmount, address _receiver) public mintCountCompliance(_mintAmount) onlyOwner {
    NFTReserve = NFTReserve - _mintAmount;
    _safeMint(_receiver, _mintAmount);
  }

  function walletOfOwner(address _owner) public view returns (uint256[] memory) {
    uint256 ownerTokenCount = balanceOf(_owner);
    uint256[] memory ownedTokenIds = new uint256[](ownerTokenCount);
    uint256 currentTokenId = _startTokenId();
    uint256 ownedTokenIndex = 0;
    address latestOwnerAddress;

    while (ownedTokenIndex < ownerTokenCount && currentTokenId <= maxSupply) {
      TokenOwnership memory ownership = _ownerships[currentTokenId];
      if (!ownership.burned && ownership.addr != address(0)) {
        latestOwnerAddress = ownership.addr;
      }
      if (latestOwnerAddress == _owner) {
        ownedTokenIds[ownedTokenIndex] = currentTokenId;
        ownedTokenIndex++;
      }
      currentTokenId++;
    }
    return ownedTokenIds;
  }


  function _startTokenId() internal view virtual override returns (uint256) {
    return 1;
  }


  function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
    require(_exists(_tokenId), 'ERC721Metadata: URI query for nonexistent token');
    string memory currentBaseURI;

    if (_tokenId <= initialMint) {
      currentBaseURI = NFTURIs[0];
    } else {
      currentBaseURI = NFTURIs[uint256(_tokenId / uriDevisor) + 1];
    }

 
    return bytes(currentBaseURI).length > 0
        ? string(abi.encodePacked(currentBaseURI, _tokenId.toString(), uriSuffix))
        : hiddenMetadataUri;
  }


  function setHiddenNum(uint256 _num) public onlyOwner {
    hidden_num = _num;
  }


  function setRewards(uint256 _RewardLevel, uint256 _RewardAmt) public onlyOwner {
     if (_RewardLevel == 25) {
       RewardAt25 = _RewardAmt;
     } else if (_RewardLevel == 250) {
       RewardAt250 = _RewardAmt;
     } else {
       RewardAt1000 = _RewardAmt;
     }
  }


  function showMyReward(address _receiver) public view returns (uint256) {
    return NFTRewards[_receiver];
  }
   

  function setNFTGroupURI(uint256 _groupIndex, string memory _NFTUriPrefix) public onlyOwner {
      require(_groupIndex < NFTURIs.length, 'Group index exceeds the group count');
      NFTURIs[_groupIndex] = _NFTUriPrefix;
    //"https://crypartists.mypinata.cloud/ipfs/CID/";
  }

  function setNFTRewardforAddress(address _receiver, uint256 _NFTCount) public onlyOwner {
     NFTRewards[_receiver] = NFTRewards[_receiver] + _NFTCount;
  }

  function setCost(uint256 _cost) public onlyOwner {
    cost = _cost;
  }


  function setReserve(uint256 _reserve) public onlyOwner {
    NFTReserve = _reserve;
  }

  function setWLCost(uint256 _wlcost) public onlyOwner {
    wlcost = _wlcost;
  }

  function setPresaleCost(uint256 _presaleCost) public onlyOwner {
    presaleCost = _presaleCost;
  }

  function setMaxSupply(uint256 _MaxSupply) public onlyOwner {
    require(_MaxSupply >= totalSupply(), 'Incorrect Max Supply');
    maxSupply = _MaxSupply;
  }



  function setMaxMintAmountPerTx(uint256 _maxMintAmountPerTx) public onlyOwner {
    require(_maxMintAmountPerTx >= 1, 'Incorrect Max Mint Amount');
    maxMintAmountPerTx = _maxMintAmountPerTx;
  }



  function setContractState(uint256 _state) public onlyOwner {
    ContractState = _state;
  }

  function setMintRewardsEnabled(bool _state) public onlyOwner {
    mintRewardsEnabled = _state;
  }


  function setMerkleRoot(bytes32 _merkleRoot) public onlyOwner {
    merkleRoot = _merkleRoot;
  }

  function withdraw() public onlyOwner nonReentrant {
    (bool os, ) = payable(owner()).call{value: address(this).balance}('');
    require(os);
  }


  function setHiddenMetadataUri(string memory _hiddenMetadataUri) public onlyOwner {
    hiddenMetadataUri = _hiddenMetadataUri;
  }

  function setUriSuffix(string memory _uriSuffix) public onlyOwner {
    uriSuffix = _uriSuffix;
  }

  function setUriPrefix(string memory _uriPrefix) public onlyOwner {
    uriPrefix = _uriPrefix;
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return uriPrefix;
  }
}
