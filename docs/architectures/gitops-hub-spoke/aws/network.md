# 허브 위치와 크로스 계정 네트워크 (AWS)

**읽는 사람**: 허브를 어느 계정에 둘지 정하고, 허브와 스포크를 실제로 잇는 사람.

**self-managed에서만 해당한다.** 관리형 Capability는 이미 클러스터 밖에서 도니 이 질문 자체가
없다([README.md](README.md)의 「어느 ArgoCD인가」 1·3번 갈림점).

---

## 1. 허브를 어디에 두는가

**기본은 "허브 = 첫 워크로드와 같은 계정"이다.** 아래 트리거 하나라도 걸리면 허브를 분리한다.

| # | 트리거 조건 | 확인 방법 |
|---|----------|----------|
| 1 | 워크로드가 **2개 이상의 AWS 계정**에 걸친다 | 계정 경계가 이미 있다면, 허브를 그중 하나에 얹는 순간 그 계정이 특권을 갖는다 |
| 2 | **계정 경계로 워크로드를 격리**해야 하는 조직·규제 요건이 있다 | 고객사 컴플라이언스팀에 확인 |
| 3 | 허브 장애가 **다른 워크로드에 번지면 안 된다** | 같은 계정이면 계정 단위 사고(서비스 한도·정책 변경)가 워크로드와 허브를 함께 덮친다 |

**셋 다 아니면 같은 계정이다.** *"나중에 커질 수도 있으니 미리 분리한다"* 는 트리거가 아니다.
필요해지면 그때 분리한다.

### 갈림점 일곱 개

| # | 갈림점 | 같은 계정 | 분리된 허브 계정 |
|---|--------|----------|-----------------|
| 1 | 배포 루트 | `<project>-infra`의 워크로드 환경이 허브를 겸한다 | `<project>-infra`에 `hub` 환경을 하나 추가한다. **저장소를 새로 만들지 않는다** |
| 2 | cluster 등록(`eks-platform-gitops`) | `server: https://kubernetes.default.svc` | 스포크의 실제 EKS API 엔드포인트 + 크로스 계정 인증 config |
| 3 | IAM 신뢰 | 불필요(같은 계정·같은 클러스터) | 스포크 계정이 신뢰 Role을 만들고 허브의 Pod Identity만 신뢰한다. **Role은 스포크가 소유**: 제약받는 쪽이 그 제약을 소유한다는 원칙([../gitops.md](../gitops.md)의 판별 2)과 같다 |
| 4 | EKS Access Entry | 불필요 | 스포크 계정마다 필요: 허브의 IAM 주체를 그 클러스터 접근 권한에 매핑([module-catalog.md](../../../module-catalog.md)의 `cross-account-trust-role` 절) |
| 5 | 장애 반경 | 허브 장애 = 그 계정 전체가 영향권 | 허브 장애 = pull만 멈춘다. desired state는 Git에 그대로 있고 워크로드 계정은 무관하다 |
| 6 | 네트워크 경로 | 불필요(같은 VPC) | 필요. 아래 2절부터 |
| 7 | state·CI 분리 | 불필요(단일 state·단일 워크플로) | 필수. 계정마다 별도 state·별도 CI job |

> `eks-platform-gitops`의 cluster Secret 계약(값이 어떻게 채워지는지)은 그 저장소 소관이다.
> 이 표는 그 계약이 기대는 **IAM 경계**만 정의한다. 실제 모듈 변수·출력 계약은
> [`module-catalog.md`](../../../module-catalog.md)가 소유한다.

### state를 계정 경계에서 나눈다

허브·스포크를 provider 2개로 한 설정에 묶어 한 apply로 처리하지 않는다. 세 가지 비용 때문이다.

1. **락 경합**: state lock 범위가 파일 하나라, 스포크 하나를 고치는 동안 허브와 다른 모든
   스포크가 함께 잠긴다.
2. **전송 비용**: S3 backend는 state 전체를 매번 통째로 주고받아 계정 수만큼 커진다.
3. **자격증명 동시 보유**: 한 CI job이 허브·스포크 양쪽 실행 Role을 동시에 들고 있어야 해,
   그 job이 침해되면 허브까지 노출된다.

---

## 2. 네트워크 경로: IAM 경계와 별개다

위 IAM 경계(신뢰 Role · Access Entry)는 "누가 인증되는가"만 답한다. **패킷이 실제로 도달하는가**는
다른 질문이고, 워크벤치 설계의 기본값(`endpoint_public_access = false`, private-only)을 스포크에도
그대로 쓰면 **답은 기본적으로 "아니오"다**. 허브와 스포크는 서로 다른 계정의 서로 다른 VPC라
연결이 저절로 생기지 않는다. 실전에서 이 공백을 IAM 경계만 만들고 놓치기 쉽다(원인이 아니라 증상만
보인다. apply는 성공하는데 허브 ArgoCD가 `dial tcp … i/o timeout`으로 스포크를 못 읽는다).

**기본은 Transit Gateway다.** 스포크가 1개뿐이어도 VPC Peering은 **선택지가 아니다**.

---

## 3. VPC Peering이 안 되는 이유

AWS 공식 문서(`vpc/latest/peering/invalid-peering-configurations.html` 「Overlapping CIDR
blocks」)가 명시한다: **"CIDR 블록이 여러 개면, 실제로 라우팅할 대역이 겹치지 않아도 그중 하나라도
겹치면 peering 자체를 생성할 수 없다."**

`vpc` 모듈의 CIDR 3계층 규약은 **pod-dup 대역(`100.64.0.0/16`, RFC 6598)을 모든 VPC가 그대로
재사용**하도록 설계돼 있다. 비라우팅 대역이라 스포크마다 조율할 필요가 없게 하려는 의도다(그래서
"dup"다). 이 설계 의도 자체가 Peering과 양립하지 않는다. 실제 라우팅 대상은 uniq 대역(예: hub
`10.53.0.0/16`·spoke `10.51.0.0/16`, 서로 겹치지 않는다)뿐인데도, 양쪽 VPC가 공유하는 dup 대역
때문에 AWS가 peering 생성 자체를 거부한다.

스포크의 pod CIDR을 재배치해 피하는 것도 해법이 아니다. 스포크가 늘 때마다 재조율해야 해서 dup
대역을 쓰는 이유 자체가 무너진다.

TGW는 스포크가 늘어도 구조를 안 바꾼다(attachment만 추가). Peering은 애초에 못 쓰므로 "스포크
1개일 때는 peering, 늘면 TGW로 전환"이라는 단계적 채택 자체가 성립하지 않는다.

---

## 4. Transit Gateway 설계

| # | 요소 | 값 |
|---|------|-----|
| 1 | 소유 계정 | **허브**: 허브가 유일한 공통 상대이므로 TGW도 허브가 영구 소유한다 |
| 2 | 공유 방식 | RAM(`aws_ram_resource_share`)으로 **스포크 계정 ID 단위** 공유. 조직 전체 공유가 아니라 정확한 계정만. IAM 신뢰와 같은 "정확한 대상만" 원칙 |
| 3 | 라우팅 | **자동 전파(propagation)를 쓰지 않는다.** 자동 전파는 VPC의 전 CIDR(uniq+dup)을 그대로 전파해 peering과 똑같은 dup 대역 충돌이 TGW 라우트테이블 안에서 재현된다. 대신 uniq 대역만 정적 라우트로 명시한다 |
| 4 | attachment 수락 | `auto_accept_shared_attachments = "enable"`: RAM 공유가 이미 계정을 좁혔으므로 수락을 자동화해도 신뢰 경계가 넓어지지 않는다 |
| 5 | `allow_external_principals` | **`true`.** 조직 내부 공유(`enable-sharing-with-aws-organization`)는 조직 **관리 계정**에서만 켤 수 있는데 배포 계정은 멤버 계정이라 그 권한이 없다. `true`로 두면 표준 계정 간 공유(초대)로 동작하고, 스포크가 초대를 수락하는 단계가 하나 늘어난다(6절) |
| 6 | 라우트테이블 소유 | **`default_route_table_association`/`_propagation` 모두 `disable`, `aws_ec2_transit_gateway_route_table`을 명시적으로 만들어 연결한다**(이유 → [conventions.md](../../../conventions.md)의 「AWS 강제 방식」). 스포크의 attachment는 RAM으로 받은 쪽이라 `transit_gateway_default_route_table_association` 인자를 못 쓰므로(AWS 공식 문서) 허브가 `aws_ec2_transit_gateway_route_table_association` + `replace_existing_association = true`로 끌어와야 한다 |
| 7 | 값 전달 | **repo 변수 수동 복사가 아니라 `data` 소스로 발견한다**: 7절 |

필요한 리소스는 소유가 두 갈래로 갈린다. TGW 자체와 그 라우트테이블은 **허브 소유**(TGW owner만
자기 라우트테이블에 라우트를 넣을 수 있다는 AWS 제약), VPC 쪽 라우트테이블은 **각자 소유**다.

| # | 리소스 | 만드는 곳 |
|---|--------|----------|
| 1 | `aws_ec2_transit_gateway` | 허브 |
| 2 | `aws_ram_resource_share` + `aws_ram_resource_association`(TGW·허브 uniq 프리픽스 리스트 둘 다) + `aws_ram_principal_association`(스포크 계정 ID) | 허브 |
| 2b | `aws_ec2_managed_prefix_list`(허브 uniq CIDR 1개, 2번의 RAM 공유에 함께 실어 보낸다, 7절) | 허브 |
| 3 | `aws_ec2_transit_gateway_vpc_attachment`(허브 자신의 attachment) | 허브 |
| 4 | CI 단계(스포크 워크플로 plan job, `tofu init` 이전)가 pending 초대를 CLI로 수락 → `data.aws_ram_resource_share`(이름으로 조회, 5번보다 먼저 필요). **Terraform 리소스가 아니다**(6절) | 스포크 |
| 5 | `aws_ec2_transit_gateway_vpc_attachment`(스포크의 attachment, 초대 수락 후 생성 가능) | 스포크 |
| 6 | 허브의 트래픽 발생원이 있는 **모든** VPC 라우트테이블 그룹(node-uniq·vm-uniq 등, 하나라도 빠지면 그 그룹의 소스는 스포크에 못 닿는다)에 스포크 uniq CIDR(하드코딩) → 허브 소유 TGW(5절) | 허브 |
| 7 | 스포크 라우트테이블(node-uniq)에 허브 uniq CIDR(하드코딩) → 스포크 자신의 attachment | 스포크 |
| 8 | `data.aws_ec2_transit_gateway_vpc_attachments`(복수형, 허브 소유 TGW에 붙은 attachment 전부 발견) → 발견된 것마다 TGW 라우트테이블에 라우트(대상 CIDR은 `vpc_owner_id`로 조회) | 허브(TGW owner만 가능) |
| 9 | 스포크 클러스터 SG에 허브발 443 인바운드(CIDR은 하드코딩) | 스포크 |

---

## 5. `for_each` key는 attachment ID가 아니라 안정값으로

6번(VPC 쪽 라우트)의 `for_each` key에 8번처럼 attachment ID를 섞어 쓰면 안 된다. 스포크를 재배포할
때마다 새 ID가 발급돼, key가 바뀔 때마다 그 리소스가 destroy+create로 강제 교체된다(Terraform 공식
문서가 피하라는 패턴). 실제로 이 destroy가 API 응답 지연으로 삭제 타임아웃에 걸려 apply가 실패했고,
재시도가 "변경 없음"으로 잘못 판단해 라우트가 며칠간 빠진 채 hub-spoke가 단절된 적이 있다.

6번의 실제 인자는 attachment ID와 무관하므로 key를 **`spoke_account_id`**(설정값, 불변)로 바꾸면
스포크를 몇 번 갈아엎어도 유지된다. **8번은 다르다**: `transit_gateway_attachment_id` 자체가
attachment ID에 의존하므로 key도 attachment ID가 맞다. 리소스의 실제 인자가 그 값에 의존하는지로
key를 고른다.

---

## 6. RAM 초대 수락: Terraform 리소스가 아니라 CI 단계다

`aws_ram_resource_share_accepter`를 스포크 root의 평범한 Terraform 리소스로 두지 않는다. 두 가지가
구조적으로 성립하지 않기 때문이다.

1. 그 리소스의 delete가 `DisassociateResourceShare`를 직접 호출해, 스포크를 파기할 때마다 허브의
   RAM 연결이 허브 state 모르게 실물에서 풀린다.
2. 재배포 시 조회용 데이터소스는 초대가 ACCEPTED여야 찾아지는데 이 리소스는 초대가 PENDING이어야
   생성(수락)돼, 서로가 서로를 막는 순환이 된다.

대신:

- 스포크 워크플로의 **plan job**(`tofu init` 이전)에 CLI 단계를 추가한다: 실행 Role을 체인 assume →
  대상 공유 이름의 PENDING 초대가 있으면 `accept-resource-share-invitation` → 없으면 no-op(멱등).
  apply job에는 필요 없다. 이 저장소는 "저장된 plan을 그대로 적용"하는 설계라 apply 시점에는 data
  source를 다시 읽지 않는다.
- 스포크 root의 `aws_ram_resource_share_accepter`는 **`removed` 블록**(destroy = false)으로
  전환한다. Terraform이 더는 이 리소스를 생성도 삭제도 하지 않으므로, teardown이 허브 쪽 RAM
  연결을 조용히 깨뜨리는 경로 자체가 사라진다. 기존에 이 리소스가 state에 있는 root만 필요하다.

이 설계로 teardown·재배포·완전 신규 배포 셋 다 사람 개입 없이 CI가 끝까지 처리한다. 자동화의
주체가 Terraform 리소스 그래프가 아니라 **CI 파이프라인의 한 단계**다.

---

## 7. 값 발견: 수동 복사 대신 `data` 소스, 단 CIDR은 예외

TGW ID·attachment ID는 AWS 무작위 부여라 결정적 합성이 불가능하지만, **그 값을 담고 있는 리소스의
이름은 결정적**이다(`ram-<workload>-hub-<region>-tgw-share`처럼 이 저장소의 네이밍 규약 그대로
조합된다). 그래서 값 자체가 아니라 **이름으로 찾아 값을 읽는다**. "하류가 다른 배포 루트라면 remote
state 참조보다 Name 태그 data source 조회를 쓴다"는 계정 내부 원칙을 계정 경계 너머로 확장한 것이다.

⛔ **태그로는 값을 실어 나를 수 없다.** AWS 태그는 종류를 가리지 않고 계정 경계를 넘지 않는다
(`describe-tags`·`DescribeTransitGatewayVpcAttachments`·RAM 데이터소스의 `tags` 전부 실측: 빈 값
또는 `null`). RAM이 명시적으로 공유하는 리소스 ARN 자체와 EC2 API가 고유 속성으로 노출하는 값
(`vpc_owner_id` 등)만 계정 경계를 넘는다.

| 필요한 값 | 발견 방법 |
|-----------|----------|
| 허브의 TGW ID | 스포크가 `data.aws_ram_resource_share`(이름, `resource_owner = "OTHER-ACCOUNTS"`)의 `resource_arns`에서 TGW ARN을 파싱: RAM의 본래 목적이라 계정 경계를 넘는다 |
| 스포크의 attachment ID·개수 | 허브가 `data.aws_ec2_transit_gateway_vpc_attachments`(복수형)로 자기 TGW에 붙은 것 전부 나열: **스포크가 0개여도 에러가 아니라 빈 리스트**라 허브 apply는 스포크 존재 여부와 무관하게 항상 성공한다 |
| 어느 attachment가 어느 스포크인가 | `data.aws_ec2_transit_gateway_vpc_attachment`(단수)의 `vpc_owner_id`: 태그가 아니라 EC2 API 고유 속성이라 계정 경계를 넘는다 |
| 허브→스포크 방향 CIDR(허브 자신의 uniq) | **관리형 접두사 목록(`aws_ec2_managed_prefix_list`)으로 발견한다.** 허브가 자기 uniq CIDR을 담은 프리픽스 리스트를 만들어 RAM 공유에 함께 실어 보낸다. 스포크는 `resource_arns`에서 `:prefix-list/`를 포함한 ARN을 파싱해 **ID만** 얻고, `aws_route`의 `destination_prefix_list_id`·SG 규칙의 `prefix_list_ids`로 직접 참조한다. 근거: [Share customer-managed prefix lists](https://docs.aws.amazon.com/vpc/latest/userguide/sharing-managed-prefix-lists.html) |
| 스포크→허브 방향 CIDR(스포크 자신의 uniq) | **여전히 하드코딩한다.** 허브는 `spoke_account_id`를 사람에게 안내받아야 하므로 같은 자리에서 CIDR도 함께 받는다(새 수동 단계가 아니라 기존 단계의 확장). 프리픽스 리스트가 자연스러운 쪽은 **1:N 발행자가 자기 값을 공표하는 방향**뿐이다. N:1로 여러 스포크의 값을 허브가 모으는 이 방향은 발행자가 여럿이라 같은 구조가 성립하지 않는다 |

⚠️ **예외: 스포크 계정 ID(와 그 CIDR)는 여전히 사람이 알려줘야 한다.** RAM `principal_association`은
공유 대상 계정을 알아야 초대를 보낼 수 있는데, 허브는 스포크가 존재하는지조차 모르는 상태에서
시작하므로 "발견"할 대상이 없다.

⚠️ **순서 제약은 하나 남는다**: 허브가 스포크보다 먼저 존재해야 한다(스포크가 이름으로 찾을 대상이
있어야 하므로). 단수형 `data.aws_ram_resource_share`는 대상이 없으면 **에러로 실패**하므로 이 순서를
거꾸로 하면 스포크 쪽에서 명확한 실패로 즉시 드러난다.
