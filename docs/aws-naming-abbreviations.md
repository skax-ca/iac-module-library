# AWS 리소스 네이밍 약어 카탈로그 (권위 참조)

> 이 문서는 `Name` 태그 조합에 사용하는 **리소스 타입 표준 약어**의 단일 진실 공급원(SSOT)이다.
> 네이밍 **포맷·어휘·강제 방식**은 [06-conventions.md](06-conventions.md)가 소유한다.

## 네이밍 포맷 (요약)

```
(resourcetype)-(workloadcode)-(env)-(regioncode)-(purpose)-(serialnumber|suffix)
     └ 이 문서가 정의        └─────────── 06-conventions.md 정의 ───────────┘
```

| 구성 요소 | 설명 | 예시 |
|-----------|------|------|
| resourcetype | 자원별 표준 약어 (이 문서) | `ec2`, `alb`, `sgr` |
| workloadcode | 프로젝트/서비스 코드 — **소비 프로젝트가 정의**(이 repo는 고정하지 않음) | `demo`, `shop` |
| env | 운영 환경 코드 | `prd`, `stg`, `dev` |
| regioncode | 리전 식별자 | `an2`, `ue1` |
| purpose | 자원의 상세 용도 | `web`, `db`, `batch`, `admin` |
| serial/suffix | 일련번호 또는 식별 접미사 | `01`, `20260415`, `policy` |

- 총 **310개** 약어, 8개 카테고리.
- 약어는 **소문자**, 리소스 타입 고유. 신규 약어 추가는 거버넌스 리뷰를 거친다.

### 신규 약어 등재 규칙 (거버넌스 리뷰 체크리스트)

새 약어는 아래 순서로 결정한다. 이 규칙은 **미래 추가**의 기준이다 — 기존 약어는 이 규칙이 정해지기
전의 결정이라 문서 끝 "기존 약어와 AWS 물리 접두사"에서 다룬다.

1. **AWS 물리 ID 접두사가 있는지 본다.** EC2 계열 리소스는 고유 ID 접두사가 있다(`rtb-`·`igw-`·`fl-`·`vpce-`…).
   약어는 `name` 인자와 `Name` 태그 **양쪽**에 쓰이므로 `name` 인자 제약을 함께 만족해야 한다.
   - 그 접두사를 리소스 `name` 인자에 그대로 쓸 수 있으면 그것을 약어로 쓴다 — `rtb`·`igw`·`fl`.
   - ⚠️ **`name` 인자가 물리 ID 접두사를 금지하면 못 쓴다** — 보안 그룹 `GroupName`은 `sg-`로 시작할
     수 없다(그 값은 SG ID로 예약, [EC2 API](https://docs.aws.amazon.com/AWSEC2/latest/APIReference/API_CreateSecurityGroup.html)).
     그래서 보안 그룹 약어는 `sg`가 아니라 `sgr`이다.
   - 접두사가 **없거나**(ALB·S3·Lambda 등 서비스 이름이 곧 자원 이름) `name` 인자 자체가 없으면
     서비스/기능 기반 약어로 만든다.
2. **같은 서비스의 프리픽스 계열을 유지한다.** 기존 항목의 패턴을 따른다(`cw*`·`msk*`·`waf*`…).
   분열된 가족은 **기존 다수 계열을 유지**한다(FSx `fx*` · API GW `agw*`/`ag*` · MemoryDB `mdb`/`md*`) —
   통일하지 않는 이유는 [`08-decisions.md`](08-decisions.md).
3. **중복·형식은 스크립트가 강제한다.** `scripts/validate-abbreviations.py` — 고유 · 소문자 · 카운트 정합.
4. **길이**: 2~5자 권장, L2 리소스 구분에 필요하면 6자까지, **7자 초과는 등재하지 않는다**
   (카탈로그 최대가 `iamoidc` 7자).
5. **등재 시 3곳을 함께 고친다**: ① 섹션 헤더 ② 상단 총계 ③ 카운트 요약 표 (스크립트가 검증).
6. **개정 이력 표에 날짜와 근거를 남긴다.**

### 종속 객체는 약어를 새로 만들지 않고 부모 이름을 상속한다

독립 식별자가 아니라 **부모 리소스에 종속된 하위 객체**는 약어를 신설하지 않고
`<부모 이름>-<역할 접미사>` 형태로 명명한다. 접미사는 위 포맷 표의 **serial/suffix 축**(`policy` 등)이다.

| 종속 객체 | 명명 | 예시 |
|-----------|------|------|
| `aws_iam_role_policy` (**inline** 정책) | `<role 이름>-policy` | `iamr-demo-prd-an2-main-flowlog-policy` |
| `aws_lb_listener` (ALB 리스너) | `<alb 이름>-listener` | `alb-demo-prd-an2-ext-01-listener` |
| `aws_lb_listener_rule` (리스너 규칙) | `<alb 이름>-rule` | `alb-demo-prd-an2-ext-01-rule` |

- **왜 상속인가**: 종속 객체는 부모 없이 존재할 수 없고 콘솔·API에서도 부모 하위에 표시된다 —
  IAM inline 정책, ALB 리스너·규칙(둘 다 `name` 인자가 없어 `Name` 태그로만 구분된다)이 그 예다.
  독립 약어를 주면 이름만으로 부모를 알 수 없어 오히려 추적성이 떨어진다.
- ⚠️ **관리형 정책(`aws_iam_policy`)은 독립 자원이므로 `iamp`를 쓴다** — 여러 role에 붙고 자체 ARN을 갖는다.
- ⚠️ inline 정책은 **`tags`를 지원하지 않는다.** 따라서 이 이름은 `Name` 태그가 아니라
  리소스의 `name` 인자 자체이고, 그것이 곧 식별자다(제약 리소스 취급 —
  [06-conventions.md](06-conventions.md)).

### 개정 이력 (승계 이후 추가된 약어)

| 날짜 | 약어 | 리소스 | 근거 |
|------|------|--------|------|
| 2026-07-30 | `fl` | VPC 플로우 로그 (`aws_flow_log`) | `modules/vpc` Task 10.3에서 필요. AWS 실제 리소스 ID 접두사(`fl-1a2b3c4d`)를 따랐다 — 이 절의 지배적 관례(`rtb`·`igw`·`eigw`·`dopt`·`pl`·`pcx`가 모두 AWS ID 접두사)와 일치한다. ⚠️ `cwfm`(CloudWatch Network Flow Monitor)·`brfl`(Bedrock Flows)은 **다른 서비스**이므로 재사용하지 않았다 |
| 2026-07-30 | `iamp` | IAM 관리형 정책 (`aws_iam_policy`) | 같은 작업에서 IAM 절에 `iamr`만 등재돼 있음을 확인. 관리형 정책은 독립 자원이라 약어가 필요하다. **inline 정책은 신설하지 않고** 위 "종속 객체" 규약으로 처리한다 |
| 2026-07-30 | `iamoidc` | IAM OIDC 신뢰 공급자 (`aws_iam_openid_connect_provider`) | 레퍼런스 소비 repo의 GitHub Actions OIDC에 필요(레퍼런스 소비 repo의 GitHub Actions OIDC). IAM 계열 프리픽스(`iamr`·`iamp`)를 유지하고 OIDC를 명시해 향후 SAML(`iamsaml`)과 대칭 확장되게 했다. 카탈로그가 이미 6자(`ecrpri`·`fmsrs`·`abkpol`)를 허용하므로 **L2 리소스 구분을 약어 길이보다 우선**했다. 기각: `iamo`(`o`가 OIDC임을 알 수 없고 짝인 `iams`가 Secret·Server certificate로 오독됨) · `iamidp`(OIDC와 SAML이 같은 약어를 공유해 L2 구분이 사라짐). ⚠️ 이 리소스는 **식별자가 URL**이라 `name` 인자가 없다 → 이 이름은 `Name` **태그로만** 붙는다(inline 정책과 반대 경우) |

---

## A.1 Compute (41)

| L0 | L2 리소스 | 약어 | Name 예시 |
|----|-----------|------|-----------|
| EC2 | 인스턴스 | `ec2` | ec2-demo-prd-an2-web-01 |
| EC2 | 시작 템플릿 | `lt` | lt-demo-prd-an2-web-01 |
| EC2 | 스팟 요청 | `sir` | sir-demo-prd-an2-batch-01 |
| EC2 | 전용 호스트 | `dh` | dh-demo-prd-an2-db-01 |
| EC2 | 용량 예약 | `cr` | cr-demo-prd-an2-web-01 |
| EC2 | 이미지 (AMI) | `ami` | ami-demo-prd-an2-web-20260415 |
| EBS | 볼륨 | `vol` | vol-demo-prd-an2-web-01 |
| EBS | 스냅샷 | `snap` | snap-demo-prd-an2-web-20260415 |
| EBS | 수명 주기 관리자 (DLM) | `dlm` | dlm-demo-prd-an2-ebs-policy |
| EC2 네트워크/보안 | 보안 그룹 | `sgr` | sgr-demo-prd-an2-web-01 |
| EC2 네트워크/보안 | 탄력적 IP | `eip` | eip-demo-prd-an2-web-01 |
| EC2 네트워크/보안 | 배치 그룹 | `pg` | pg-demo-prd-an2-hpc-01 |
| EC2 네트워크/보안 | 키 페어 | `kp` | kp-demo-prd-an2-admin-key |
| EC2 네트워크/보안 | 네트워크 인터페이스 | `eni` | eni-demo-prd-an2-web-01 |
| 로드 밸런싱 | ALB | `alb` | alb-demo-prd-an2-ext-01 |
| 로드 밸런싱 | NLB | `nlb` | nlb-demo-prd-an2-ext-01 |
| 로드 밸런싱 | GLB | `glb` | glb-demo-prd-an2-fw-01 |
| 로드 밸런싱 | 대상 그룹 | `tg` | tg-demo-prd-an2-web-01 |
| 로드 밸런싱 | Trust Store | `ts` | ts-demo-prd-an2-auth-01 |
| Auto Scaling | Auto Scaling 그룹 | `asg` | asg-demo-prd-an2-web-01 |
| Lambda | 함수 | `lfn` | lfn-demo-prd-an2-proc-01 |
| Lambda | 애플리케이션 | `lapp` | lapp-demo-prd-an2-svc-01 |
| Lambda | 코드 서명 구성 | `lcsc` | lcsc-demo-prd-an2-signer-01 |
| Lambda | 계층 (Layer) | `llyr` | llyr-demo-prd-an2-lib-01 |
| AWS Batch | 작업 (Job) | `batj` | batj-demo-prd-an2-dailysync-01 |
| AWS Batch | 작업 정의 | `batjd` | batjd-demo-prd-an2-etltask-01 |
| AWS Batch | 작업 대기열 | `batjq` | batjq-demo-prd-an2-highpriority-01 |
| AWS Batch | 컴퓨팅 환경 | `batce` | batce-demo-prd-an2-fargate-01 |
| AWS Batch | 소모성 리소스 | `batcr` | batcr-demo-prd-an2-gpu-01 |
| AWS Batch | 예약 정책 | `batsp` | batsp-demo-prd-an2-fair-share |
| ECS | 클러스터 | `ecs` | ecs-demo-prd-an2-main-01 |
| ECS | 네임스페이스 | `ecsn` | ecsn-demo-prd-an2-internal-ns |
| ECS | 태스크 정의 | `ecstd` | ecstd-demo-prd-an2-webapp-01 |
| ECS | 대몬 태스크 정의 | `ecstdd` | ecstdd-demo-prd-an2-logagent-01 |
| ECS | ECS 서비스 | `ecssvc` | ecssvc-demo-prd-an2-api-01 |
| EKS | 클러스터 | `eks` | eks-demo-prd-an2-main-01 |
| EKS | 노드 그룹 | `eksn` | eksn-demo-prd-an2-worker-01 |
| EKS | Fargate 프로파일 | `eksf` | eksf-demo-prd-an2-app-01 |
| EKS Anywhere | Anywhere 클러스터 | `eksa` | eksa-demo-prd-an2-onprem-01 |
| ECR | 프라이빗 리포지토리 | `ecrpri` | ecrpri-demo-prd-an2-web-01 |
| ECR | 퍼블릭 리포지토리 | `ecrpub` | ecrpub-demo-prd-an2-lib-01 |

## A.2 Network (71)

| L0 | L2 리소스 | 약어 | Name 예시 |
|----|-----------|------|-----------|
| VPC | VPC | `vpc` | vpc-demo-prd-an2-main |
| VPC | 서브넷 | `snet` | snet-demo-prd-an2-pub-dup1-a-100.64.0.0/28 |
| VPC | 라우팅 테이블 | `rtb` | rtb-demo-prd-an2-pub-dup1-a |
| VPC | 인터넷 게이트웨이 | `igw` | igw-demo-prd-an2-main |
| VPC | 송신 전용 인터넷 GW | `eigw` | eigw-demo-prd-an2-ipv6 |
| VPC | DHCP 옵션 세트 | `dopt` | dopt-demo-prd-an2-main |
| VPC | 관리형 접두사 목록 | `pl` | pl-demo-prd-an2-internal |
| VPC | NAT 게이트웨이 | `ngw` | ngw-demo-prd-an2-pub-uniq1-a |
| VPC | 피어링 연결 | `pcx` | pcx-demo-prd-an2-to-legacy |
| VPC | 플로우 로그 | `fl` | fl-demo-prd-an2-main |
| VPC 보안 | 네트워크 ACL | `nacl` | nacl-demo-prd-an2-pub-01 |
| PrivateLink & Lattice | 엔드포인트 | `vpce` | vpce-demo-prd-an2-s3-if |
| PrivateLink & Lattice | 엔드포인트 서비스 | `vpces` | vpces-demo-prd-an2-api |
| PrivateLink & Lattice | 서비스 네트워크 | `vlsn` | vlsn-demo-prd-an2-mesh |
| PrivateLink & Lattice | Lattice 서비스 | `vls` | vls-demo-prd-an2-order-svc |
| PrivateLink & Lattice | 리소스 구성 | `vlrc` | vlrc-demo-prd-an2-db-conf |
| PrivateLink & Lattice | 리소스 게이트웨이 | `vlrg` | vlrg-demo-prd-an2-main |
| DNS / 네트워크 방화벽 | DNS 규칙 그룹 | `dfwg` | dfwg-demo-prd-an2-block-list |
| DNS / 네트워크 방화벽 | 네트워크 방화벽 | `nfw` | nfw-demo-prd-an2-inspection |
| DNS / 네트워크 방화벽 | 방화벽 정책 | `nfwp` | nfwp-demo-prd-an2-default |
| VPN | 고객 게이트웨이 | `cgw` | cgw-demo-prd-an2-office-01 |
| VPN | 가상 프라이빗 GW | `vgw` | vgw-demo-prd-an2-main |
| VPN | VPN 연결 | `vpn` | vpn-demo-prd-an2-site-to-site-01 |
| VPN | Client VPN 엔드포인트 | `cvpn` | cvpn-demo-prd-an2-remote-01 |
| Transit Gateway | Transit Gateway | `tgw` | tgw-demo-prd-an2-hub |
| Transit Gateway | TGW 연결 | `tgwa` | tgwa-demo-prd-an2-vpc-main |
| Transit Gateway | TGW 라우팅 테이블 | `tgwrt` | tgwrt-demo-prd-an2-default |
| 트래픽 미러링 | 미러 세션 | `tms` | tms-demo-prd-an2-analy-01 |
| 트래픽 미러링 | 미러 대상 | `tmt` | tmt-demo-prd-an2-collector-01 |
| Route 53 | 호스트 영역 | `hz` | hz-demo-prd-an2-service-com |
| Route 53 | 상태 검사 | `hc` | hc-demo-prd-an2-web-01 |
| Route 53 | 프로필 | `prof` | prof-demo-prd-an2-main |
| Route 53 | 글로벌 해석기 | `gr` | gr-demo-prd-an2-main |
| Route 53 해석기 | 인바운드 엔드포인트 | `r53ie` | r53ie-demo-prd-an2-dc-01 |
| Route 53 해석기 | 아웃바운드 엔드포인트 | `r53oe` | r53oe-demo-prd-an2-to-ext-01 |
| Route 53 해석기 | 규칙 (Resolver Rule) | `r53r` | r53r-demo-prd-an2-forward-01 |
| Route 53 해석기 | 쿼리 로깅 구성 | `ql` | ql-demo-prd-an2-audit-01 |
| Route 53 도메인 | 등록된 도메인 | `dom` | dom-demo-prd-an2-service-com |
| Route 53 IP 라우팅 | CIDR 모음 | `cidr` | cidr-demo-prd-an2-office |
| Route 53 트래픽 흐름 | 트래픽 정책 | `tp` | tp-demo-prd-an2-failover-01 |
| Route 53 트래픽 흐름 | 정책 레코드 | `pr` | pr-demo-prd-an2-web-01 |
| CloudFront | 배포 (Distribution) | `cfd` | cfd-demo-prd-an2-web-01 |
| CloudFront | 정책 (Policy) | `cfpt` | cfpt-demo-prd-an2-cache-std |
| CloudFront | 함수 (Function) | `cffn` | cffn-demo-prd-an2-auth-check |
| CloudFront | Static IPs | `cfsi` | cfsi-demo-prd-an2-global-01 |
| CloudFront | VPC 오리진 | `cfvo` | cfvo-demo-prd-an2-alb-origin |
| CloudFront SaaS | Multi-tenant distributions | `mtd` | mtd-demo-prd-an2-saas-01 |
| CloudFront SaaS | Distribution tenants | `dtnt` | dtnt-demo-prd-an2-client-a |
| CloudFront 보안 | 원본 액세스 (OAC/OAI) | `cfoa` | cfoa-demo-prd-an2-s3-secure |
| CloudFront 보안 | Trust stores | `cfts` | cfts-demo-prd-an2-viewer-01 |
| CloudFront 보안 | 필드 수준 암호화 | `cffe` | cffe-demo-prd-an2-user-info |
| CloudFront 키 관리 | 퍼블릭 키 | `cfpk` | cfpk-demo-prd-an2-signer-01 |
| CloudFront 키 관리 | 키 그룹 | `cfkg` | cfkg-demo-prd-an2-trusted-apps |
| API Gateway | REST API | `agwr` | agwr-demo-prd-an2-user-api-01 |
| API Gateway | HTTP API | `agwh` | agwh-demo-prd-an2-log-api-01 |
| API Gateway | WebSocket API | `agww` | agww-demo-prd-an2-chat-api-01 |
| API Gateway | 사용자 지정 도메인 | `agcd` | agcd-demo-prd-an2-api-demo-com |
| API Gateway | VPC 링크 | `agvl` | agvl-demo-prd-an2-nlb-01 |
| API Gateway | AgentCore 대상 | `agac` | agac-demo-prd-an2-target-01 |
| API Gateway 내부 | 스테이지 | `agst` | agst-demo-prd-an2-v1 |
| API Gateway 내부 | 권한 부여 객체 | `agaz` | agaz-demo-prd-an2-lambda-auth-01 |
| API Gateway 내부 | 모델 | `agmd` | agmd-demo-prd-an2-user-schema |
| API Gateway 관리/보안 | 사용량 계획 | `agup` | agup-demo-prd-an2-silver-01 |
| API Gateway 관리/보안 | API 키 | `agak` | agak-demo-prd-an2-partner-a-01 |
| API Gateway 관리/보안 | 클라이언트 인증서 | `agcc` | agcc-demo-prd-an2-internal-01 |
| Direct Connect | 연결 (Connection) | `dxc` | dxc-demo-prd-an2-kdx-01 |
| Direct Connect | 가상 인터페이스 (VIF) | `dxv` | dxv-demo-prd-an2-priv-01 |
| Direct Connect | LAG | `dxl` | dxl-demo-prd-an2-main-01 |
| Direct Connect | Direct Connect GW | `dxgw` | dxgw-demo-prd-an2-global-hub |
| Direct Connect | AWS 인터커넥트 | `dxic` | dxic-demo-prd-an2-partner-01 |
| Direct Connect | Last Mile Interconnect | `dxlm` | dxlm-demo-prd-an2-site-a-01 |

> ⚠️ DX 게이트웨이 연결(`aws_dx_gateway_association`)은 DX 전용 약어를 만들지 않는다 — 연결 대상이
> VPC 자원이므로 그 약어를 그대로 쓴다: 가상 프라이빗 GW `vgw`(VPN) · 전송 게이트웨이 `tgw`(Transit Gateway).
> DX 절의 독립 자원 약어는 `dxgw`(Direct Connect Gateway)뿐이다.

## A.3 Databases (39)

| L0 | L2 리소스 | 약어 | Name 예시 |
|----|-----------|------|-----------|
| RDS Aurora | Aurora MySQL 클러스터 | `army` | army-demo-prd-an2-web-01 |
| RDS Aurora | Aurora PostgreSQL 클러스터 | `arpg` | arpg-demo-prd-an2-order-01 |
| RDS | MySQL 인스턴스 | `rdmy` | rdmy-demo-prd-an2-batch-01 |
| RDS | PostgreSQL 인스턴스 | `rdpg` | rdpg-demo-prd-an2-user-01 |
| RDS | MariaDB 인스턴스 | `rdma` | rdma-demo-prd-an2-temp-01 |
| RDS | Oracle 인스턴스 | `rdor` | rdor-demo-prd-an2-erp-01 |
| RDS | SQL Server 인스턴스 | `rdms` | rdms-demo-prd-an2-legacy-01 |
| RDS | IBM Db2 인스턴스 | `rdb2` | rdb2-demo-prd-an2-finance-01 |
| RDS 관리 | DB 프록시 | `rdp` | rdp-demo-prd-an2-proxy-01 |
| RDS 관리 | DB 스냅샷 | `rdsn` | rdsn-demo-prd-an2-daily-20260415 |
| RDS 관리 | DB 서브넷 그룹 | `rdsg` | rdsg-demo-prd-an2-db-group |
| RDS 관리 | DB 인스턴스 파라미터 그룹 | `rdipg` | rdipg-demo-prd-an2-db-aurora-mysql-id |
| RDS 관리 | DB 클러스터 파라미터 그룹 | `rdcpg` | rdcpg-demo-prd-an2-db-aurora-mysql-id |
| RDS 관리 | DB 옵션 그룹 | `rdog` | rdog-demo-prd-an2-db-mysql-id |
| DocumentDB | DocumentDB 클러스터 | `docc` | docc-demo-prd-an2-msg-01 |
| DocumentDB | DocumentDB 인스턴스 | `doci` | doci-demo-prd-an2-msg-01 |
| DocumentDB 관리 | DB 스냅샷 | `dcsn` | dcsn-demo-prd-an2-daily-20260424 |
| DocumentDB 관리 | DB 서브넷 그룹 | `dcsg` | dcsg-demo-prd-an2-db-group |
| DocumentDB 관리 | DB 클러스터 파라미터 그룹 | `dcpc` | dcpc-demo-prd-an2-db-document-id |
| DynamoDB | 테이블 | `ddb` | ddb-demo-prd-an2-user-table-01 |
| DynamoDB | 백업 | `ddbs` | ddbs-demo-prd-an2-user-20260415 |
| DynamoDB | 예약 용량 | `ddrc` | ddrc-demo-prd-an2-reserved |
| ElastiCache | Valkey 캐시 | `ecvk` | ecvk-demo-prd-an2-session-01 |
| ElastiCache | Redis OSS 캐시 | `ecrs` | ecrs-demo-prd-an2-cache-01 |
| ElastiCache | Memcached 캐시 | `ecmc` | ecmc-demo-prd-an2-short-01 |
| ElastiCache | 글로벌 데이터 스토어 | `ecg` | ecg-demo-prd-an2-global-hub |
| ElastiCache 구성 | 서브넷 그룹 | `ecsg` | ecsg-demo-prd-an2-cache-group |
| ElastiCache 구성 | 파라미터 그룹 | `ecpg` | ecpg-demo-prd-an2-cache-params |
| ElastiCache 구성 | 사용자/사용자 그룹 | `ecu` | ecu-demo-prd-an2-admin-01 |
| MemoryDB | 클러스터 | `mdb` | mdb-demo-prd-an2-main-01 |
| MemoryDB | 스냅샷 | `mdsn` | mdsn-demo-prd-an2-backup-20260415 |
| MemoryDB 보안 | 액세스 제어 목록 (ACL) | `mdacl` | mdacl-demo-prd-an2-default |
| MemoryDB 구성 | 서브넷 그룹 | `mdsg` | mdsg-demo-prd-an2-mem-group |
| Keyspaces | 키스페이스 | `ksk` | ksk-demo-prd-an2-log-space |
| Keyspaces | 테이블 | `kst` | kst-demo-prd-an2-event-01 |
| Neptune | 클러스터 | `npt` | npt-demo-prd-an2-graph-01 |
| Neptune | 스냅샷 | `npts` | npts-demo-prd-an2-backup-20260415 |
| Neptune | 그래프 | `nptg` | nptg-demo-prd-an2-relation-analysis |
| Neptune | 노트북 인스턴스 | `nptn` | nptn-demo-prd-an2-dev-nb-01 |

## A.4 Storage (33)

| L0 | L2 리소스 | 약어 | Name 예시 |
|----|-----------|------|-----------|
| S3 | 범용 버킷 | `s3` | s3-demo-prd-an2-log-01 |
| S3 | 디렉터리 버킷 | `s3d` | s3d-demo-prd-an2-high-speed-01 |
| S3 | 테이블 버킷 | `s3t` | s3t-demo-prd-an2-analytics-01 |
| S3 | 벡터 버킷 | `s3v` | s3v-demo-prd-an2-rag-data-01 |
| S3 | 파일 시스템 | `s3fs` | s3fs-demo-prd-an2-nfs-01 |
| S3 액세스 | 액세스 지점 | `sap` | sap-demo-prd-an2-readonly-01 |
| S3 액세스 | FSx용 액세스 포인트 | `sapx` | sapx-demo-prd-an2-fsx-01 |
| S3 액세스 | Access Grants | `sag` | sag-demo-prd-an2-default |
| S3 액세스 | Access Analyzer | `saa` | saa-demo-prd-an2-main |
| S3 관리 | Storage Lens | `sl` | sl-demo-prd-an2-dashboard |
| S3 관리 | 배치 작업 | `sbo` | sbo-demo-prd-an2-tagging-01 |
| EFS | 파일 시스템 | `efs` | efs-demo-prd-an2-shared-01 |
| EFS | 액세스 포인트 | `eap` | eap-demo-prd-an2-app-data-01 |
| FSx | 파일 시스템 | `fsx` | fsx-demo-prd-an2-lustre-01 |
| FSx | 볼륨 | `fxv` | fxv-demo-prd-an2-ontap-01 |
| FSx | 파일 캐시 | `fxc` | fxc-demo-prd-an2-repo-01 |
| FSx | 백업 | `fxb` | fxb-demo-prd-an2-daily-20260415 |
| FSx ONTAP | 스토리지 가상 머신 | `fsvm` | fsvm-demo-prd-an2-ontap-01 |
| FSx OpenZFS | 스냅샷 | `fzsn` | fzsn-demo-prd-an2-snap-20260415 |
| Storage Gateway | 게이트웨이 | `sgw` | sgw-demo-prd-an2-office-01 |
| Storage Gateway | 파일 공유 | `sgfs` | sgfs-demo-prd-an2-s3-share-01 |
| Storage Gateway | 볼륨 | `sgv` | sgv-demo-prd-an2-cached-01 |
| Storage Gateway | 테이프 | `sgt` | sgt-demo-prd-an2-archive-01 |
| Storage Gateway | 풀 (Pool) | `sgp` | sgp-demo-prd-an2-tape-pool |
| AWS Backup | 백업 볼트 (Vault) | `abkv` | abkv-demo-prd-an2-main-vault |
| AWS Backup | 백업 계획 (Plan) | `abkp` | abkp-demo-prd-an2-daily-plan |
| AWS Backup | 멀웨어 보호 | `abkm` | abkm-demo-prd-an2-s3-scan |
| AWS Backup | 복원 테스트 | `abkrt` | abkrt-demo-prd-an2-weekly-test |
| AWS Backup | 법적 보존 (Hold) | `abkl` | abkl-demo-prd-an2-audit-hold |
| AWS Backup | 게이트웨이/가상머신 | `abkg` | abkg-demo-prd-an2-onprem-vm |
| AWS Backup | 백업 정책 | `abkpol` | abkpol-demo-prd-an2-org-std |
| AWS Backup | 감사 프레임워크 | `abkaf` | abkaf-demo-prd-an2-compliance |
| AWS Backup | 보고서 | `abkar` | abkar-demo-prd-an2-monthly-rpt |

## A.5 Analytics, AI, ML (47)

| L0 | L2 리소스 | 약어 | Name 예시 |
|----|-----------|------|-----------|
| Athena | 작업 그룹 | `atwg` | atwg-demo-prd-an2-log-anal-01 |
| Athena | 용량 예약 | `atcr` | atcr-demo-prd-an2-main-01 |
| Athena | 데이터 소스 | `atds` | atds-demo-prd-an2-s3-catalog |
| Athena | 워크플로 | `atwf` | atwf-demo-prd-an2-daily-etl |
| EMR Serverless | 애플리케이션 | `emrs` | emrs-demo-prd-an2-spark-app-01 |
| EMR EC2 | 클러스터 | `emrc` | emrc-demo-prd-an2-hadoop-01 |
| EMR EC2 | 노트북/리포지토리 | `emnb` | emnb-demo-prd-an2-dev-01 |
| EMR EKS | 가상 클러스터 | `emrv` | emrv-demo-prd-an2-eks-vcl-01 |
| EMR Studio | 스튜디오/워크스페이스 | `emst` | emst-demo-prd-an2-team-a-01 |
| Redshift Serverless | 워크그룹 | `rswg` | rswg-demo-prd-an2-dw-01 |
| Redshift Serverless | 네임스페이스 | `rsns` | rsns-demo-prd-an2-main-db |
| Redshift Cluster | 클러스터 | `rsc` | rsc-demo-prd-an2-finance-01 |
| Redshift Integration | 데이터 공유 | `rsds` | rsds-demo-prd-an2-to-external |
| Redshift 구성 | 서브넷 그룹 | `rssg` | rssg-demo-prd-an2-dw-group |
| Glue Data Catalog | 데이터베이스 | `gdb` | gdb-demo-prd-an2-raw-db |
| Glue Data Catalog | 테이블 | `gtbl` | gtbl-demo-prd-an2-user-log |
| Glue Data Catalog | 크롤러 | `gcrw` | gcrw-demo-prd-an2-s3-scan-01 |
| Glue Data Catalog | 연결 (Connection) | `gcon` | gcon-demo-prd-an2-rds-link |
| Glue ETL | ETL 작업 (Job) | `gjob` | gjob-demo-prd-an2-daily-load-01 |
| Glue ETL | 트리거 | `gtrg` | gtrg-demo-prd-an2-cron-01 |
| Glue ETL | 워크플로 | `gwf` | gwf-demo-prd-an2-end-to-end |
| Firehose | Firehose 스트림 | `fhs` | fhs-demo-prd-an2-s3-delivery-01 |
| MSK | 클러스터 | `mskc` | mskc-demo-prd-an2-main-01 |
| MSK | 클러스터 구성 | `mskf` | mskf-demo-prd-an2-std-conf |
| MSK | 복제기 (Replicator) | `mskr` | mskr-demo-prd-an2-dr-sync-01 |
| MSK Connect | 커넥터 | `mskn` | mskn-demo-prd-an2-s3-sink-01 |
| MSK Connect | 플러그인 | `mskp` | mskp-demo-prd-an2-debezium-01 |
| OpenSearch Managed | 도메인 (Domain) | `osd` | osd-demo-prd-an2-search-01 |
| OpenSearch Managed | 패키지 (Package) | `ospk` | ospk-demo-prd-an2-plugin-01 |
| OpenSearch Serverless | 컬렉션 (Collection) | `osc` | osc-demo-prd-an2-vector-01 |
| OpenSearch Serverless | 컬렉션 그룹 | `oscg` | oscg-demo-prd-an2-main-group |
| OpenSearch Serverless | 데이터 액세스 정책 | `osap` | osap-demo-prd-an2-read-only |
| OpenSearch Serverless | 네트워크 정책 | `osnp` | osnp-demo-prd-an2-vpc-only |
| OpenSearch Serverless | 암호화 정책 | `osep` | osep-demo-prd-an2-kms-std |
| OpenSearch Serverless | 수명 주기 정책 | `oslp` | oslp-demo-prd-an2-retention |
| OpenSearch Ingestion | 파이프라인 (Pipeline) | `ospp` | ospp-demo-prd-an2-s3-to-os-01 |
| OpenSearch 공통 | VPC 엔드포인트 | `osvpce` | osvpce-demo-prd-an2-os-01 |
| Bedrock | 에이전트 (Agent) | `brag` | brag-demo-prd-an2-cs-helper-01 |
| Bedrock | 흐름 (Flows) | `brfl` | brfl-demo-prd-an2-data-pipeline-01 |
| Bedrock | 지식 기반 | `brkb` | brkb-demo-prd-an2-internal-wiki-01 |
| Bedrock | 가드레일 (Guardrails) | `brgr` | brgr-demo-prd-an2-standard-filter |
| Bedrock | 프롬프트 관리 | `brpm` | brpm-demo-prd-an2-system-msg-01 |
| Bedrock Infer | 추론 프로파일 | `brip` | brip-demo-prd-an2-us-east-failover |
| Bedrock Infer | 배치 추론 | `brbi` | brbi-demo-prd-an2-daily-summary-01 |
| Bedrock 튜닝 | 프롬프트 라우터 모델 | `brrm` | brrm-demo-prd-an2-cost-optimizer |
| Bedrock 튜닝 | 모델 배포 (PT) | `brpt` | brpt-demo-prd-an2-claude3-sonnet-01 |
| Bedrock 평가 | 평가 (Evaluation) | `brev` | brev-demo-prd-an2-qa-bench-01 |

## A.6 Security, Identity, Compliance (18)

| L0 | L2 리소스 | 약어 | Name 예시 |
|----|-----------|------|-----------|
| IAM | 역할 (Role) | `iamr` | iamr-demo-prd-an2-ebs-csi |
| IAM | 정책 (관리형, `aws_iam_policy`) | `iamp` | iamp-demo-prd-an2-s3-read |
| IAM | OIDC 신뢰 공급자 (`aws_iam_openid_connect_provider`) | `iamoidc` | iamoidc-demo-prd-an2-gha |
| ACM | 인증서 (Certificate) | `acmc` | acmc-demo-prd-an2-wildcard-01 |
| KMS | 고객 관리형 키 | `kmsk` | kmsk-demo-prd-an2-s3-01 |
| KMS | 외부 키 스토어 | `kmss` | kmss-demo-prd-an2-hsm-01 |
| Secrets Manager | 보안 암호 (Secret) | `sec` | sec-demo-prd-an2-db-pass-01 |
| GuardDuty | Malware Protection | `gdp` | gdp-demo-prd-an2-malware |
| WAF | 웹 ACL (Web ACL) | `wafl` | wafl-demo-prd-an2-web-01 |
| WAF | IP 세트 (IP Set) | `wafis` | wafis-demo-prd-an2-blocklist-01 |
| WAF | 규칙 그룹 (Rule Group) | `wafrg` | wafrg-demo-prd-an2-common-01 |
| WAF | 정규식 패턴 세트 | `wafrs` | wafrs-demo-prd-an2-sql-inj |
| Shield | 보호된 리소스 (Protection) | `shld` | shld-demo-prd-an2-alb-01 |
| Firewall Manager | 보안 정책 (Policy) | `fmsp` | fmsp-demo-prd-an2-org-std |
| Firewall Manager | 리소스 세트 | `fmsrs` | fmsrs-demo-prd-an2-vpc-group |
| Firewall Manager | 프로토콜 목록 | `fmspl` | fmspl-demo-prd-an2-allowed |
| Cognito | 사용자 풀 (User Pool) | `cup` | cup-demo-prd-an2-app-user-01 |
| Cognito | 자격 증명 풀 (Identity Pool) | `cip` | cip-demo-prd-an2-web-auth-01 |

## A.7 Management, Governance (30)

| L0 | L2 리소스 | 약어 | Name 예시 |
|----|-----------|------|-----------|
| CloudWatch | 대시보드 | `cwdb` | cwdb-demo-prd-an2-main |
| CloudWatch | 경보 (Alarm) | `cwal` | cwal-demo-prd-an2-cpu-high-01 |
| CloudWatch 생성형 AI | 모델 간접 호출 감시 | `cwai` | cwai-demo-prd-an2-bedrock-01 |
| CloudWatch 생성형 AI | Bedrock AgentCore | `cwba` | cwba-demo-prd-an2-cs-helper-01 |
| CloudWatch App Signals | 서비스 수준 목표 (SLO) | `cwslo` | cwslo-demo-prd-an2-latency-std |
| CloudWatch App Signals | Synthetics Canary | `cwcy` | cwcy-demo-prd-an2-api-check-01 |
| CloudWatch App Signals | RUM App Monitor | `cwrm` | cwrm-demo-prd-an2-frontend-01 |
| CloudWatch 인프라 | Container Insights | `cwci` | cwci-demo-prd-an2-eks-main |
| CloudWatch 인프라 | Lambda Insights | `cwli` | cwli-demo-prd-an2-data-proc |
| CloudWatch 로그 | 로그 그룹 (Log Group) | `cwlg` | cwlg-demo-prd-an2-app-server |
| CloudWatch 로그 | 로그 분석 (Insights) | `cwlli` | cwlli-demo-prd-an2-error-check |
| CloudWatch 지표 | 메트릭 스트림 | `cwms` | cwms-demo-prd-an2-to-s3-01 |
| CloudWatch 네트워크 | 인터넷 모니터 | `cwim` | cwim-demo-prd-an2-global |
| CloudWatch 네트워크 | 흐름 모니터 (Flow) | `cwfm` | cwfm-demo-prd-an2-vpc-main |
| CloudTrail | 추적 (Trail) | `cttr` | cttr-demo-prd-an2-management-log |
| CloudTrail | 이벤트 데이터 스토어 | `ctds` | ctds-demo-prd-an2-security-anal-01 |
| CloudTrail | 통합 (Channel) | `ctch` | ctch-demo-prd-an2-external-audit |
| Config | 규정 준수 팩 | `cfgcp` | cfgcp-demo-prd-an2-nist-pack |
| Config | 규칙 (Rule) | `cfgr` | cfgr-demo-prd-an2-s3-public-check |
| Config | 애그리게이터 | `cfga` | cfga-demo-prd-an2-org-total |
| Config | 고급 쿼리 | `cfgaq` | cfgaq-demo-prd-an2-resource-inv |
| SSM | 세션 관리자 | `ssmsm` | ssmsm-demo-prd-an2-audit-log |
| SSM | 패치 관리자 | `ssmpm` | ssmpm-demo-prd-an2-linux-std |
| SSM | 상태 관리자 | `ssmst` | ssmst-demo-prd-an2-web-config |
| SSM | 자동화 (Automation) | `ssma` | ssma-demo-prd-an2-ec2-stop-start |
| SSM | 문서 (Document) | `ssmd` | ssmd-demo-prd-an2-harden-script |
| SSM | 파라미터 스토어 | `ssmps` | ssmps-demo-prd-an2-db-url |
| SSM | AppConfig | `ssmac` | ssmac-demo-prd-an2-feature-flag |
| CloudFormation | 스택 (Stack) | `cfns` | cfns-demo-prd-an2-network-base-01 |
| CloudFormation | StackSet | `cfnss` | cfnss-demo-prd-an2-security-std |

## A.8 Developer Tools, Others (31)

| L0 | L2 리소스 | 약어 | Name 예시 |
|----|-----------|------|-----------|
| CodeCommit | 리포지토리 | `ccr` | ccr-demo-prd-an2-webapp-01 |
| CodeCommit | 승인 규칙 템플릿 | `ccat` | ccat-demo-prd-an2-review-01 |
| CodeConnections | 연결 (Connection) | `ccon` | ccon-demo-prd-an2-gitops-01 |
| CodeBuild | 프로젝트 빌드 | `cbp` | cbp-demo-prd-an2-webbuild-01 |
| CodeBuild | 보고서 그룹 | `cbrg` | cbrg-demo-prd-an2-unittest-01 |
| CodeDeploy | 애플리케이션 | `cda` | cda-demo-prd-an2-web-svc-01 |
| CodeDeploy | 배포 구성 | `cdc` | cdc-demo-prd-an2-canary-std |
| CodePipeline | 파이프라인 | `cpn` | cpn-demo-prd-an2-web-01 |
| Step Functions | 상태 머신 | `sfsm` | sfsm-demo-prd-an2-order-01 |
| Step Functions | 활동 (Activity) | `sfact` | sfact-demo-prd-an2-manual-01 |
| Resilience Hub | 애플리케이션 | `rhapp` | rhapp-demo-prd-an2-svc-01 |
| Resilience Hub | 정책 (Policy) | `rhpol` | rhpol-demo-prd-an2-critical-01 |
| Resilience Hub | 실험 템플릿 | `rhet` | rhet-demo-prd-an2-fail-01 |
| Resilience Hub | 실험 (Experiment) | `rhex` | rhex-demo-prd-an2-test-01 |
| Prometheus | 워크스페이스 | `prow` | prow-demo-prd-an2-main-01 |
| Prometheus | 관리형 콜렉터 | `proc` | proc-demo-prd-an2-eks-01 |
| SNS | 주제 (Topic) | `snst` | snst-demo-prd-an2-alarm-01 |
| SNS | 구독 (Subscription) | `snss` | snss-demo-prd-an2-email-01 |
| SNS | 푸시 알림 | `snsp` | snsp-demo-prd-an2-push-01 |
| SQS | 대기열 (Queue) | `sqs` | sqs-demo-prd-an2-job-01 |
| EventBridge | 이벤트 버스 | `ebus` | ebus-demo-prd-an2-custom-01 |
| EventBridge | 규칙 (Rule) | `ebru` | ebru-demo-prd-an2-ec2-monitor-01 |
| EventBridge | 파이프 (Pipe) | `ebpp` | ebpp-demo-prd-an2-pipe-01 |
| EventBridge | 일정 (Schedule) | `ebsc` | ebsc-demo-prd-an2-dailytask-01 |
| EventBridge | 일정 그룹 | `ebsg` | ebsg-demo-prd-an2-batch-01 |
| EventBridge | 스키마 | `ebsk` | ebsk-demo-prd-an2-user-01 |
| DMS | 태스크 (Task) | `dmst` | dmst-demo-prd-an2-db-01 |
| DMS | 엔드포인트 | `dmse` | dmse-demo-prd-an2-src-01 |
| DMS | 복제 인스턴스 | `dmsi` | dmsi-demo-prd-an2-main-01 |
| DMS | 서브넷 그룹 | `dmsg` | dmsg-demo-prd-an2-main-01 |
| DMS | 데이터 수집기 | `dmsc` | dmsc-demo-prd-an2-ora-01 |

---

## 카테고리 카운트 요약

| # | 카테고리 | 약어 수 |
|---|----------|--------:|
| A.1 | Compute | 41 |
| A.2 | Network | 71 |
| A.3 | Databases | 39 |
| A.4 | Storage | 33 |
| A.5 | Analytics, AI, ML | 47 |
| A.6 | Security, Identity, Compliance | 18 |
| A.7 | Management, Governance | 30 |
| A.8 | Developer Tools, Others | 31 |
| | **합계** | **310** |

> ⚠️ **총계는 세 곳에 있다** — 상단 서술, 섹션 헤더 "(NN)", 이 표. 셋이 어긋나면 SSOT를
> 신뢰할 수 없으므로, **약어를 추가·삭제할 때는 ① 섹션 헤더 ② 상단 총계 ③ 이 표를 함께 고친다.**
> `scripts/validate-abbreviations.py`가 세 값의 일치를 강제한다.

---

## 기존 약어와 AWS 물리 접두사

| 약어 | AWS 물리 ID | 비고 |
|---|---|---|
| `snet` | `subnet-` | 근거 미기록 |
| `sgr` | `sg-` | 위 등재 규칙 1항 — 보안 그룹 `GroupName`이 `sg-`로 시작할 수 없다 |
| `ngw` | `nat-` | 근거 미기록 |
| `nacl` | `acl-` | 근거 미기록 |
| `kp` | `key-` | 근거 미기록 |
| `dh` | `h-` | 물리 ID가 1자(`h-`)라 name 토큰으로 무의미 — 서비스 기반 |

이 약어들은 등재 규칙이 정해지기 **전**의 결정이고, 비고는 현재 사실만 적었다 — 기록에 없는 사유를
재구성하지 않는다. 마이그레이션은 하지 않는다(릴리스된 `modules/vpc`가 실사용 중, 기각 근거는
[`08-decisions.md`](08-decisions.md)).
