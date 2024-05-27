// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./interface/DaoTokenInterface.sol";
import "./interface/DaoInterface.sol";
import "./interface/DonationInterface.sol";
import "./DaoToken.sol";

contract Donation is DonationInterface {
    ///////////// @notice 아래에 변수 추가 ////////////

    /// @notice Admin 주소
    address admin;

    /// @notice 캠페인 아이디 카운트
    uint256 count;

    /// @notice DAO 토큰 컨트랙트 주소
    DaoTokenInterface daoToken;

    ///////////// @notice 아래에 매핑 추가 ////////////

    /// @notice 캠페인 아이디 -> 캠페인 구조체
    mapping(uint256 => Campaign) public campaigns;

    /// @notice 캠페인 아이디 -> 사용자 주소 -> 기부 금액
    mapping(uint256 => mapping(address => uint256)) public pledgedUserToAmount;

    ///////////// @notice 아래에 생성자 및 컨트랙트 주소 설정 ////////////
    constructor(address _admin, DaoTokenInterface _daoToken) {
        /// @notice 관리자 및 DAO Token 컨트랙트 주소 설정
        admin = _admin;
        daoToken = _daoToken;
    }

    ///////////// @notice 아래에 modifier 추가 ////////////

    /// @notice 관리자만 접근 가능하도록 설정
    modifier onlyAdmin() {
        require(msg.sender == admin, "Admin required.");
        _;
    }

    /// @notice DAO 회원만 접근 가능하도록 설정

    function launch(
        address _target,
        string memory _title,
        string memory _description,
        uint256 _goal,
        uint32 _startAt,
        uint32 _endAt
    ) external {
        require(_startAt > block.timestamp, "start at < now");
        require(_endAt > _startAt, "end at < start at");
        require(_endAt - _startAt <= 86400 * 90, "The maximum allowed campaign duration is 90 days.");
        count += 1;
        Campaign memory campaign = Campaign(
            msg.sender,
            _target,
            _title,
            _description,
            _goal,
            0,
            _startAt,
            _endAt,
            false
        );
        campaigns[count] = campaign;

        emit Launch(count, campaign);
    }

    function cancel(uint256 _campaignId) external {
        Campaign memory campaign = campaigns[_campaignId];
        require(campaign.creator == msg.sender, "Only creator can cancel");
        require(block.timestamp < campaign.startAt, "Already Started");
        delete campaigns[_campaignId];
        emit Cancel(_campaignId);
    }

    function pledge(uint256 _campaignId, uint256 _amount) external {
        Campaign memory campaign = campaigns[_campaignId];
        require(block.timestamp >= campaign.startAt, "Not Started");
        require(getIsEnded(_campaignId) == false, "Campaign ended");
        require(_amount > 0, "Amount must be greater than zero");
        campaigns[_campaignId].pledged += _amount;
        pledgedUserToAmount[_campaignId][msg.sender] = _amount;
        require(daoToken.transferFrom(msg.sender, address(0), _amount));
        emit Pledge(_campaignId, msg.sender, _amount, campaign.pledged);
    }

    function unpledge(uint256 _campaignId, uint256 _amount) external {
        Campaign memory campaign = campaigns[_campaignId];
        require(_amount > 0, "Amount must be greater than zero");
        require(getIsEnded(_campaignId) == false, "Campaign ended");
        require(
            pledgedUserToAmount[_campaignId][msg.sender] >= _amount,
            "Unpledge amount must be smaller than the amount you pledged"
        );
        campaigns[_campaignId].pledged -= _amount;
        pledgedUserToAmount[_campaignId][msg.sender] -= _amount;
        require(daoToken.transferFrom(address(0), msg.sender, _amount));
        emit Unpledge(_campaignId, msg.sender, _amount, campaign.pledged);
    }

    //2. onlyDao modifier 추가
    function claim(uint256 _campaignId) external {
        require(getIsEnded(_campaignId), "Campaign not ended");
        Campaign memory campaign = campaigns[_campaignId];
        require(campaign.claimed == false, "Already claimed");
        require(daoToken.transferFrom(address(0), campaign.target, campaign.pledged));
        campaigns[_campaignId].claimed == true;
        emit Claim(_campaignId, true, campaign.pledged);
    }

    function refund(uint256 _campaignId) external {
        require(getIsEnded(_campaignId), "Campaign not ended");
        uint256 bal = pledgedUserToAmount[_campaignId][msg.sender];
        pledgedUserToAmount[_campaignId][msg.sender] = 0;
        require(daoToken.transferFrom(address(0), msg.sender, bal));
        emit Refund(_campaignId, msg.sender, bal);
    }

    ///////////// @notice 아래에 get함수는 필요한 경우 주석을 해제해 사용해주세요 ////////////

    function getIsEnded(uint256 _campaignId) public view returns (bool) {
        Campaign memory campaign = campaigns[_campaignId];
        return block.timestamp >= campaign.endAt || campaign.pledged >= campaign.goal;
    }

    function getCampaign(uint256 _campaignId) external view returns (Campaign memory) {
        return campaigns[_campaignId];
    }

    function getCampaignCreator(uint256 _campaignId) external view returns (address) {
        return campaigns[_campaignId].creator;
    }

    function getCampaignGoal(uint256 _campaignId) external view returns (uint256) {
        return campaigns[_campaignId].goal;
    }

    function getCampaignTotalAmount(uint256 _campaignId) external view returns (uint256) {
        return campaigns[_campaignId].pledged;
    }
}
