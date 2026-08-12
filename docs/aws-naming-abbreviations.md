# AWS 리소스 네이밍 약어 카탈로그 (권위 참조)

> 이 문서는 `Name` 태그 조합에 사용하는 **리소스 타입 표준 약어**의 단일 진실 공급원(SSOT)이다.
> 네이밍 **포맷·어휘·강제 방식**은 [06-conventions.md](06-conventions.md) §2가 소유한다.

## 네이밍 포맷 (요약)

```
(resourcetype)-(workloadcode)-(env)-(regioncode)-(purpose)-(serialnumber|suffix)
     └ 이 문서가 정의        └──── 02-naming-tagging-and-pinning.md 정의 ────┘
```

| 구성 요소 | 설명 | 예시 |
|-----------|------|------|
| resourcetype | 자원별 표준 약어 (이 문서) | `ec2`, `alb`, `sgr` |
| workloadcode | 프로젝트/서비스 코드 — **소비 프로젝트가 정의**(이 repo는 고정하지 않음) | `acme`, `shop` |
| env | 운영 환경 코드 | `prd`, `stg`, `dev` |
| regioncode | 리전 식별자 | `an2`, `ue1` |
| purpose | 자원의 상세 용도 | `web`, `db`, `batch`, `admin` |
| serial/suffix | 일련번호 또는 식별 접미사 | `01`, `20260415`, `policy` |

- 총 **312개** 약어, 8개 카테고리.
- 약어는 **소문자**, 리소스 타입 고유. 신규 약어 추가는 거버넌스 리뷰를 거친다.

### 종속 객체는 약어를 새로 만들지 않고 부모 이름을 상속한다

독립 식별자가 아니라 **부모 리소스에 종속된 하위 객체**는 약어를 신설하지 않고
`<부모 이름>-<역할 접미사>` 형태로 명명한다. 접미사는 위 포맷 표의 **serial/suffix 축**(`policy` 등)이다.

| 종속 객체 | 명명 | 예시 |
|-----------|------|------|
| `aws_iam_role_policy` (**inline** 정책) | `<role 이름>-policy` | `iamr-acme-prd-an2-main-flowlog-policy` |

- **왜 상속인가**: inline 정책은 role 없이 존재할 수 없고 IAM 콘솔·API에서도 role 하위에 표시된다.
  독립 약어를 주면 이름만으로 부모를 알 수 없어 오히려 추적성이 떨어진다.
- ⚠️ **관리형 정책(`aws_iam_policy`)은 독립 자원이므로 `iamp`를 쓴다** — 여러 role에 붙고 자체 ARN을 갖는다.
- ⚠️ inline 정책은 **`tags`를 지원하지 않는다.** 따라서 이 이름은 `Name` 태그가 아니라
  리소스의 `name` 인자 자체이고, 그것이 곧 식별자다(제약 리소스 취급 —
  [06-conventions.md](06-conventions.md) §2).

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
| EC2 | 인스턴스 | `ec2` | ec2-acme-prd-an2-web-01 |
| EC2 | 시작 템플릿 | `lt` | lt-acme-prd-an2-web-01 |
| EC2 | 스팟 요청 | `sir` | sir-acme-prd-an2-batch-01 |
| EC2 | 전용 호스트 | `dh` | dh-acme-prd-an2-db-01 |
| EC2 | 용량 예약 | `cr` | cr-acme-prd-an2-web-01 |
| EC2 | 이미지 (AMI) | `ami` | ami-acme-prd-an2-web-20260415 |
| EBS | 볼륨 | `vol` | vol-acme-prd-an2-web-01 |
| EBS | 스냅샷 | `snap` | snap-acme-prd-an2-web-20260415 |
| EBS | 수명 주기 관리자 (DLM) | `dlm` | dlm-acme-prd-an2-ebs-policy |
| EC2 네트워크/보안 | 보안 그룹 | `sgr` | sgr-acme-prd-an2-web-01 |
| EC2 네트워크/보안 | 탄력적 IP | `eip` | eip-acme-prd-an2-web-01 |
| EC2 네트워크/보안 | 배치 그룹 | `pg` | pg-acme-prd-an2-hpc-01 |
| EC2 네트워크/보안 | 키 페어 | `kp` | kp-acme-prd-an2-admin-key |
| EC2 네트워크/보안 | 네트워크 인터페이스 | `eni` | eni-acme-prd-an2-web-01 |
| 로드 밸런싱 | ALB | `alb` | alb-acme-prd-an2-ext-01 |
| 로드 밸런싱 | NLB | `nlb` | nlb-acme-prd-an2-ext-01 |
| 로드 밸런싱 | GLB | `glb` | glb-acme-prd-an2-fw-01 |
| 로드 밸런싱 | 대상 그룹 | `tg` | tg-acme-prd-an2-web-01 |
| 로드 밸런싱 | Trust Store | `ts` | ts-acme-prd-an2-auth-01 |
| Auto Scaling | Auto Scaling 그룹 | `asg` | asg-acme-prd-an2-web-01 |
| Lambda | 함수 | `lfn` | lfn-acme-prd-an2-proc-01 |
| Lambda | 애플리케이션 | `lapp` | lapp-acme-prd-an2-svc-01 |
| Lambda | 코드 서명 구성 | `lcsc` | lcsc-acme-prd-an2-signer-01 |
| Lambda | 계층 (Layer) | `llyr` | llyr-acme-prd-an2-lib-01 |
| AWS Batch | 작업 (Job) | `batj` | batj-acme-prd-an2-dailysync-01 |
| AWS Batch | 작업 정의 | `batjd` | batjd-acme-prd-an2-etltask-01 |
| AWS Batch | 작업 대기열 | `batjq` | batjq-acme-prd-an2-highpriority-01 |
| AWS Batch | 컴퓨팅 환경 | `batce` | batce-acme-prd-an2-fargate-01 |
| AWS Batch | 소모성 리소스 | `batcr` | batcr-acme-prd-an2-gpu-01 |
| AWS Batch | 예약 정책 | `batsp` | batsp-acme-prd-an2-fair-share |
| ECS | 클러스터 | `ecs` | ecs-acme-prd-an2-main-01 |
| ECS | 네임스페이스 | `ens` | ens-acme-prd-an2-internal-ns |
| ECS | 태스크 정의 | `etd` | etd-acme-prd-an2-webapp-01 |
| ECS | 대몬 태스크 정의 | `edtd` | edtd-acme-prd-an2-logagent-01 |
| ECS | ECS 서비스 | `esvc` | esvc-acme-prd-an2-api-01 |
| EKS | 클러스터 | `eks` | eks-acme-prd-an2-main-01 |
| EKS | 노드 그룹 | `eksn` | eksn-acme-prd-an2-worker-01 |
| EKS | Fargate 프로파일 | `eksf` | eksf-acme-prd-an2-app-01 |
| EKS Anywhere | Anywhere 클러스터 | `eksa` | eksa-acme-prd-an2-onprem-01 |
| ECR | 프라이빗 리포지토리 | `ecrpri` | ecrpri-acme-prd-an2-web-01 |
| ECR | 퍼블릭 리포지토리 | `ecrpub` | ecrpub-acme-prd-an2-lib-01 |

## A.2 Network (73)

| L0 | L2 리소스 | 약어 | Name 예시 |
|----|-----------|------|-----------|
| VPC | VPC | `vpc` | vpc-acme-prd-an2-main |
| VPC | 서브넷 | `snet` | snet-acme-prd-an2-pub-dup1-a-100.64.0.0/28 |
| VPC | 라우팅 테이블 | `rtb` | rtb-acme-prd-an2-pub-dup1-a |
| VPC | 인터넷 게이트웨이 | `igw` | igw-acme-prd-an2-main |
| VPC | 송신 전용 인터넷 GW | `eigw` | eigw-acme-prd-an2-ipv6 |
| VPC | DHCP 옵션 세트 | `dopt` | dopt-acme-prd-an2-main |
| VPC | 관리형 접두사 목록 | `pl` | pl-acme-prd-an2-internal |
| VPC | NAT 게이트웨이 | `ngw` | ngw-acme-prd-an2-pub-uniq1-a |
| VPC | 피어링 연결 | `pcx` | pcx-acme-prd-an2-to-legacy |
| VPC | 플로우 로그 | `fl` | fl-acme-prd-an2-main |
| VPC 보안 | 네트워크 ACL | `nacl` | nacl-acme-prd-an2-pub-01 |
| PrivateLink & Lattice | 엔드포인트 | `vpce` | vpce-acme-prd-an2-s3-if |
| PrivateLink & Lattice | 엔드포인트 서비스 | `vpces` | vpces-acme-prd-an2-api |
| PrivateLink & Lattice | 서비스 네트워크 | `vlsn` | vlsn-acme-prd-an2-mesh |
| PrivateLink & Lattice | Lattice 서비스 | `vls` | vls-acme-prd-an2-order-svc |
| PrivateLink & Lattice | 리소스 구성 | `vlrc` | vlrc-acme-prd-an2-db-conf |
| PrivateLink & Lattice | 리소스 게이트웨이 | `vlrg` | vlrg-acme-prd-an2-main |
| DNS / 네트워크 방화벽 | DNS 규칙 그룹 | `dfwg` | dfwg-acme-prd-an2-block-list |
| DNS / 네트워크 방화벽 | 네트워크 방화벽 | `nfw` | nfw-acme-prd-an2-inspection |
| DNS / 네트워크 방화벽 | 방화벽 정책 | `nfwp` | nfwp-acme-prd-an2-default |
| VPN | 고객 게이트웨이 | `cgw` | cgw-acme-prd-an2-office-01 |
| VPN | 가상 프라이빗 GW | `vgw` | vgw-acme-prd-an2-main |
| VPN | VPN 연결 | `vpn` | vpn-acme-prd-an2-site-to-site-01 |
| VPN | Client VPN 엔드포인트 | `cvpn` | cvpn-acme-prd-an2-remote-01 |
| Transit Gateway | Transit Gateway | `tgw` | tgw-acme-prd-an2-hub |
| Transit Gateway | TGW 연결 | `tgwa` | tgwa-acme-prd-an2-vpc-main |
| Transit Gateway | TGW 라우팅 테이블 | `tgwrt` | tgwrt-acme-prd-an2-default |
| 트래픽 미러링 | 미러 세션 | `tms` | tms-acme-prd-an2-analy-01 |
| 트래픽 미러링 | 미러 대상 | `tmt` | tmt-acme-prd-an2-collector-01 |
| Route 53 | 호스트 영역 | `hz` | hz-acme-prd-an2-service-com |
| Route 53 | 상태 검사 | `hc` | hc-acme-prd-an2-web-01 |
| Route 53 | 프로필 | `prof` | prof-acme-prd-an2-main |
| Route 53 | 글로벌 해석기 | `gr` | gr-acme-prd-an2-main |
| Route 53 해석기 | 인바운드 엔드포인트 | `r53ie` | r53ie-acme-prd-an2-dc-01 |
| Route 53 해석기 | 아웃바운드 엔드포인트 | `r53oe` | r53oe-acme-prd-an2-to-ext-01 |
| Route 53 해석기 | 규칙 (Resolver Rule) | `r53r` | r53r-acme-prd-an2-forward-01 |
| Route 53 해석기 | 쿼리 로깅 구성 | `ql` | ql-acme-prd-an2-audit-01 |
| Route 53 도메인 | 등록된 도메인 | `dom` | dom-acme-prd-an2-service-com |
| Route 53 IP 라우팅 | CIDR 모음 | `cidr` | cidr-acme-prd-an2-office |
| Route 53 트래픽 흐름 | 트래픽 정책 | `tp` | tp-acme-prd-an2-failover-01 |
| Route 53 트래픽 흐름 | 정책 레코드 | `pr` | pr-acme-prd-an2-web-01 |
| CloudFront | 배포 (Distribution) | `cfd` | cfd-acme-prd-an2-web-01 |
| CloudFront | 정책 (Policy) | `cfpt` | cfpt-acme-prd-an2-cache-std |
| CloudFront | 함수 (Function) | `cffn` | cffn-acme-prd-an2-auth-check |
| CloudFront | Static IPs | `cfsi` | cfsi-acme-prd-an2-global-01 |
| CloudFront | VPC 오리진 | `cfvo` | cfvo-acme-prd-an2-alb-origin |
| CloudFront SaaS | Multi-tenant distributions | `mtd` | mtd-acme-prd-an2-saas-01 |
| CloudFront SaaS | Distribution tenants | `dtnt` | dtnt-acme-prd-an2-client-a |
| CloudFront 보안 | 원본 액세스 (OAC/OAI) | `cfoa` | cfoa-acme-prd-an2-s3-secure |
| CloudFront 보안 | Trust stores | `cfts` | cfts-acme-prd-an2-viewer-01 |
| CloudFront 보안 | 필드 수준 암호화 | `cffe` | cffe-acme-prd-an2-user-info |
| CloudFront 키 관리 | 퍼블릭 키 | `cfpk` | cfpk-acme-prd-an2-signer-01 |
| CloudFront 키 관리 | 키 그룹 | `cfkg` | cfkg-acme-prd-an2-trusted-apps |
| API Gateway | REST API | `agwr` | agwr-acme-prd-an2-user-api-01 |
| API Gateway | HTTP API | `agwh` | agwh-acme-prd-an2-log-api-01 |
| API Gateway | WebSocket API | `agww` | agww-acme-prd-an2-chat-api-01 |
| API Gateway | 사용자 지정 도메인 | `agcd` | agcd-acme-prd-an2-api-acme-com |
| API Gateway | VPC 링크 | `agvl` | agvl-acme-prd-an2-nlb-01 |
| API Gateway | AgentCore 대상 | `agac` | agac-acme-prd-an2-target-01 |
| API Gateway 내부 | 스테이지 | `agst` | agst-acme-prd-an2-v1 |
| API Gateway 내부 | 권한 부여 객체 | `agaz` | agaz-acme-prd-an2-lambda-auth-01 |
| API Gateway 내부 | 모델 | `agmd` | agmd-acme-prd-an2-user-schema |
| API Gateway 관리/보안 | 사용량 계획 | `agup` | agup-acme-prd-an2-silver-01 |
| API Gateway 관리/보안 | API 키 | `agak` | agak-acme-prd-an2-partner-a-01 |
| API Gateway 관리/보안 | 클라이언트 인증서 | `agcc` | agcc-acme-prd-an2-internal-01 |
| Direct Connect | 연결 (Connection) | `dxc` | dxc-acme-prd-an2-kdx-01 |
| Direct Connect | 가상 인터페이스 (VIF) | `dxv` | dxv-acme-prd-an2-priv-01 |
| Direct Connect | LAG | `dxl` | dxl-acme-prd-an2-main-01 |
| Direct Connect | Direct Connect GW | `dxgw` | dxgw-acme-prd-an2-global-hub |
| Direct Connect | 가상 프라이빗 GW | `dxvgw` | dxvgw-acme-prd-an2-main |
| Direct Connect | 전송 게이트웨이 | `dxtgw` | dxtgw-acme-prd-an2-hub |
| Direct Connect | AWS 인터커넥트 | `dxic` | dxic-acme-prd-an2-partner-01 |
| Direct Connect | Last Mile Interconnect | `dxlm` | dxlm-acme-prd-an2-site-a-01 |

## A.3 Databases (39)

| L0 | L2 리소스 | 약어 | Name 예시 |
|----|-----------|------|-----------|
| RDS Aurora | Aurora MySQL 클러스터 | `army` | army-acme-prd-an2-web-01 |
| RDS Aurora | Aurora PostgreSQL 클러스터 | `arpg` | arpg-acme-prd-an2-order-01 |
| RDS | MySQL 인스턴스 | `rdmy` | rdmy-acme-prd-an2-batch-01 |
| RDS | PostgreSQL 인스턴스 | `rdpg` | rdpg-acme-prd-an2-user-01 |
| RDS | MariaDB 인스턴스 | `rdma` | rdma-acme-prd-an2-temp-01 |
| RDS | Oracle 인스턴스 | `rdor` | rdor-acme-prd-an2-erp-01 |
| RDS | SQL Server 인스턴스 | `rdms` | rdms-acme-prd-an2-legacy-01 |
| RDS | IBM Db2 인스턴스 | `rdb2` | rdb2-acme-prd-an2-finance-01 |
| RDS 관리 | DB 프록시 | `rdp` | rdp-acme-prd-an2-proxy-01 |
| RDS 관리 | DB 스냅샷 | `rdsn` | rdsn-acme-prd-an2-daily-20260415 |
| RDS 관리 | DB 서브넷 그룹 | `rdsg` | rdsg-acme-prd-an2-db-group |
| RDS 관리 | DB 인스턴스 파라미터 그룹 | `rdipg` | rdipg-acme-prd-an2-db-aurora-mysql-id |
| RDS 관리 | DB 클러스터 파라미터 그룹 | `rdcpg` | rdcpg-acme-prd-an2-db-aurora-mysql-id |
| RDS 관리 | DB 옵션 그룹 | `rdog` | rdog-acme-prd-an2-db-mysql-id |
| DocumentDB | DocumentDB 클러스터 | `docc` | docc-acme-prd-an2-msg-01 |
| DocumentDB | DocumentDB 인스턴스 | `doci` | doci-acme-prd-an2-msg-01 |
| DocumentDB 관리 | DB 스냅샷 | `dcsn` | dcsn-acme-prd-an2-daily-20260424 |
| DocumentDB 관리 | DB 서브넷 그룹 | `dcsg` | dcsg-acme-prd-an2-db-group |
| DocumentDB 관리 | DB 클러스터 파라미터 그룹 | `dcpc` | dcpc-acme-prd-an2-db-document-id |
| DynamoDB | 테이블 | `ddb` | ddb-acme-prd-an2-user-table-01 |
| DynamoDB | 백업 | `ddbs` | ddbs-acme-prd-an2-user-20260415 |
| DynamoDB | 예약 용량 | `ddrc` | ddrc-acme-prd-an2-reserved |
| ElastiCache | Valkey 캐시 | `ecvk` | ecvk-acme-prd-an2-session-01 |
| ElastiCache | Redis OSS 캐시 | `ecrs` | ecrs-acme-prd-an2-cache-01 |
| ElastiCache | Memcached 캐시 | `ecmc` | ecmc-acme-prd-an2-short-01 |
| ElastiCache | 글로벌 데이터 스토어 | `ecg` | ecg-acme-prd-an2-global-hub |
| ElastiCache 구성 | 서브넷 그룹 | `ecsg` | ecsg-acme-prd-an2-cache-group |
| ElastiCache 구성 | 파라미터 그룹 | `ecpg` | ecpg-acme-prd-an2-cache-params |
| ElastiCache 구성 | 사용자/사용자 그룹 | `ecu` | ecu-acme-prd-an2-admin-01 |
| MemoryDB | 클러스터 | `mdb` | mdb-acme-prd-an2-main-01 |
| MemoryDB | 스냅샷 | `mdsn` | mdsn-acme-prd-an2-backup-20260415 |
| MemoryDB 보안 | 액세스 제어 목록 (ACL) | `mdacl` | mdacl-acme-prd-an2-default |
| MemoryDB 구성 | 서브넷 그룹 | `mdsg` | mdsg-acme-prd-an2-mem-group |
| Keyspaces | 키스페이스 | `ksk` | ksk-acme-prd-an2-log-space |
| Keyspaces | 테이블 | `kst` | kst-acme-prd-an2-event-01 |
| Neptune | 클러스터 | `npt` | npt-acme-prd-an2-graph-01 |
| Neptune | 스냅샷 | `npts` | npts-acme-prd-an2-backup-20260415 |
| Neptune | 그래프 | `nptg` | nptg-acme-prd-an2-relation-analysis |
| Neptune | 노트북 인스턴스 | `nptn` | nptn-acme-prd-an2-dev-nb-01 |

## A.4 Storage (33)

| L0 | L2 리소스 | 약어 | Name 예시 |
|----|-----------|------|-----------|
| S3 | 범용 버킷 | `s3` | s3-acme-prd-an2-log-01 |
| S3 | 디렉터리 버킷 | `s3d` | s3d-acme-prd-an2-high-speed-01 |
| S3 | 테이블 버킷 | `s3t` | s3t-acme-prd-an2-analytics-01 |
| S3 | 벡터 버킷 | `s3v` | s3v-acme-prd-an2-rag-data-01 |
| S3 | 파일 시스템 | `s3fs` | s3fs-acme-prd-an2-nfs-01 |
| S3 액세스 | 액세스 지점 | `sap` | sap-acme-prd-an2-readonly-01 |
| S3 액세스 | FSx용 액세스 포인트 | `sapx` | sapx-acme-prd-an2-fsx-01 |
| S3 액세스 | Access Grants | `sag` | sag-acme-prd-an2-default |
| S3 액세스 | Access Analyzer | `saa` | saa-acme-prd-an2-main |
| S3 관리 | Storage Lens | `sl` | sl-acme-prd-an2-dashboard |
| S3 관리 | 배치 작업 | `sbo` | sbo-acme-prd-an2-tagging-01 |
| EFS | 파일 시스템 | `efs` | efs-acme-prd-an2-shared-01 |
| EFS | 액세스 포인트 | `eap` | eap-acme-prd-an2-app-data-01 |
| FSx | 파일 시스템 | `fsx` | fsx-acme-prd-an2-lustre-01 |
| FSx | 볼륨 | `fxv` | fxv-acme-prd-an2-ontap-01 |
| FSx | 파일 캐시 | `fxc` | fxc-acme-prd-an2-repo-01 |
| FSx | 백업 | `fxb` | fxb-acme-prd-an2-daily-20260415 |
| FSx ONTAP | 스토리지 가상 머신 | `fsvm` | fsvm-acme-prd-an2-ontap-01 |
| FSx OpenZFS | 스냅샷 | `fzsn` | fzsn-acme-prd-an2-snap-20260415 |
| Storage Gateway | 게이트웨이 | `sgw` | sgw-acme-prd-an2-office-01 |
| Storage Gateway | 파일 공유 | `sgfs` | sgfs-acme-prd-an2-s3-share-01 |
| Storage Gateway | 볼륨 | `sgv` | sgv-acme-prd-an2-cached-01 |
| Storage Gateway | 테이프 | `sgt` | sgt-acme-prd-an2-archive-01 |
| Storage Gateway | 풀 (Pool) | `sgp` | sgp-acme-prd-an2-tape-pool |
| AWS Backup | 백업 볼트 (Vault) | `abkv` | abkv-acme-prd-an2-main-vault |
| AWS Backup | 백업 계획 (Plan) | `abkp` | abkp-acme-prd-an2-daily-plan |
| AWS Backup | 멀웨어 보호 | `abkm` | abkm-acme-prd-an2-s3-scan |
| AWS Backup | 복원 테스트 | `abkrt` | abkrt-acme-prd-an2-weekly-test |
| AWS Backup | 법적 보존 (Hold) | `abkl` | abkl-acme-prd-an2-audit-hold |
| AWS Backup | 게이트웨이/가상머신 | `abkg` | abkg-acme-prd-an2-onprem-vm |
| AWS Backup | 백업 정책 | `abkpol` | abkpol-acme-prd-an2-org-std |
| AWS Backup | 감사 프레임워크 | `abkaf` | abkaf-acme-prd-an2-compliance |
| AWS Backup | 보고서 | `abkar` | abkar-acme-prd-an2-monthly-rpt |

## A.5 Analytics, AI, ML (47)

| L0 | L2 리소스 | 약어 | Name 예시 |
|----|-----------|------|-----------|
| Athena | 작업 그룹 | `atwg` | atwg-acme-prd-an2-log-anal-01 |
| Athena | 용량 예약 | `atcr` | atcr-acme-prd-an2-main-01 |
| Athena | 데이터 소스 | `atds` | atds-acme-prd-an2-s3-catalog |
| Athena | 워크플로 | `atwf` | atwf-acme-prd-an2-daily-etl |
| EMR Serverless | 애플리케이션 | `emrs` | emrs-acme-prd-an2-spark-app-01 |
| EMR EC2 | 클러스터 | `emrc` | emrc-acme-prd-an2-hadoop-01 |
| EMR EC2 | 노트북/리포지토리 | `emnb` | emnb-acme-prd-an2-dev-01 |
| EMR EKS | 가상 클러스터 | `emrv` | emrv-acme-prd-an2-eks-vcl-01 |
| EMR Studio | 스튜디오/워크스페이스 | `emst` | emst-acme-prd-an2-team-a-01 |
| Redshift Serverless | 워크그룹 | `rswg` | rswg-acme-prd-an2-dw-01 |
| Redshift Serverless | 네임스페이스 | `rsns` | rsns-acme-prd-an2-main-db |
| Redshift Cluster | 클러스터 | `rsc` | rsc-acme-prd-an2-finance-01 |
| Redshift Integration | 데이터 공유 | `rsds` | rsds-acme-prd-an2-to-external |
| Redshift 구성 | 서브넷 그룹 | `rssg` | rssg-acme-prd-an2-dw-group |
| Glue Data Catalog | 데이터베이스 | `gdb` | gdb-acme-prd-an2-raw-db |
| Glue Data Catalog | 테이블 | `gtbl` | gtbl-acme-prd-an2-user-log |
| Glue Data Catalog | 크롤러 | `gcrw` | gcrw-acme-prd-an2-s3-scan-01 |
| Glue Data Catalog | 연결 (Connection) | `gcon` | gcon-acme-prd-an2-rds-link |
| Glue ETL | ETL 작업 (Job) | `gjob` | gjob-acme-prd-an2-daily-load-01 |
| Glue ETL | 트리거 | `gtrg` | gtrg-acme-prd-an2-cron-01 |
| Glue ETL | 워크플로 | `gwf` | gwf-acme-prd-an2-end-to-end |
| Firehose | Firehose 스트림 | `fhs` | fhs-acme-prd-an2-s3-delivery-01 |
| MSK | 클러스터 | `mskc` | mskc-acme-prd-an2-main-01 |
| MSK | 클러스터 구성 | `mskf` | mskf-acme-prd-an2-std-conf |
| MSK | 복제기 (Replicator) | `mskr` | mskr-acme-prd-an2-dr-sync-01 |
| MSK Connect | 커넥터 | `mskn` | mskn-acme-prd-an2-s3-sink-01 |
| MSK Connect | 플러그인 | `mskp` | mskp-acme-prd-an2-debezium-01 |
| OpenSearch Managed | 도메인 (Domain) | `osd` | osd-acme-prd-an2-search-01 |
| OpenSearch Managed | 패키지 (Package) | `ospk` | ospk-acme-prd-an2-plugin-01 |
| OpenSearch Serverless | 컬렉션 (Collection) | `osc` | osc-acme-prd-an2-vector-01 |
| OpenSearch Serverless | 컬렉션 그룹 | `oscg` | oscg-acme-prd-an2-main-group |
| OpenSearch Serverless | 데이터 액세스 정책 | `osap` | osap-acme-prd-an2-read-only |
| OpenSearch Serverless | 네트워크 정책 | `osnp` | osnp-acme-prd-an2-vpc-only |
| OpenSearch Serverless | 암호화 정책 | `osep` | osep-acme-prd-an2-kms-std |
| OpenSearch Serverless | 수명 주기 정책 | `oslp` | oslp-acme-prd-an2-retention |
| OpenSearch Ingestion | 파이프라인 (Pipeline) | `ospp` | ospp-acme-prd-an2-s3-to-os-01 |
| OpenSearch 공통 | VPC 엔드포인트 | `osvpce` | osvpce-acme-prd-an2-os-01 |
| Bedrock | 에이전트 (Agent) | `brag` | brag-acme-prd-an2-cs-helper-01 |
| Bedrock | 흐름 (Flows) | `brfl` | brfl-acme-prd-an2-data-pipeline-01 |
| Bedrock | 지식 기반 | `brkb` | brkb-acme-prd-an2-internal-wiki-01 |
| Bedrock | 가드레일 (Guardrails) | `brgr` | brgr-acme-prd-an2-standard-filter |
| Bedrock | 프롬프트 관리 | `brpm` | brpm-acme-prd-an2-system-msg-01 |
| Bedrock Infer | 추론 프로파일 | `brip` | brip-acme-prd-an2-us-east-failover |
| Bedrock Infer | 배치 추론 | `brbi` | brbi-acme-prd-an2-daily-summary-01 |
| Bedrock 튜닝 | 프롬프트 라우터 모델 | `brrm` | brrm-acme-prd-an2-cost-optimizer |
| Bedrock 튜닝 | 모델 배포 (PT) | `brpt` | brpt-acme-prd-an2-claude3-sonnet-01 |
| Bedrock 평가 | 평가 (Evaluation) | `brev` | brev-acme-prd-an2-qa-bench-01 |

## A.6 Security, Identity, Compliance (18)

| L0 | L2 리소스 | 약어 | Name 예시 |
|----|-----------|------|-----------|
| IAM | 역할 (Role) | `iamr` | iamr-acme-prd-an2-ebs-csi |
| IAM | 정책 (관리형, `aws_iam_policy`) | `iamp` | iamp-acme-prd-an2-s3-read |
| IAM | OIDC 신뢰 공급자 (`aws_iam_openid_connect_provider`) | `iamoidc` | iamoidc-acme-prd-an2-gha |
| ACM | 인증서 (Certificate) | `acmc` | acmc-acme-prd-an2-wildcard-01 |
| KMS | 고객 관리형 키 | `kmsk` | kmsk-acme-prd-an2-s3-01 |
| KMS | 외부 키 스토어 | `kmss` | kmss-acme-prd-an2-hsm-01 |
| Secrets Manager | 보안 암호 (Secret) | `sec` | sec-acme-prd-an2-db-pass-01 |
| GuardDuty | Malware Protection | `gdp` | gdp-acme-prd-an2-malware |
| WAF | 웹 ACL (Web ACL) | `wafl` | wafl-acme-prd-an2-web-01 |
| WAF | IP 세트 (IP Set) | `wafis` | wafis-acme-prd-an2-blocklist-01 |
| WAF | 규칙 그룹 (Rule Group) | `wafrg` | wafrg-acme-prd-an2-common-01 |
| WAF | 정규식 패턴 세트 | `wafrs` | wafrs-acme-prd-an2-sql-inj |
| Shield | 보호된 리소스 (Protection) | `shld` | shld-acme-prd-an2-alb-01 |
| Firewall Manager | 보안 정책 (Policy) | `fmsp` | fmsp-acme-prd-an2-org-std |
| Firewall Manager | 리소스 세트 | `fmsrs` | fmsrs-acme-prd-an2-vpc-group |
| Firewall Manager | 프로토콜 목록 | `fmspl` | fmspl-acme-prd-an2-allowed |
| Cognito | 사용자 풀 (User Pool) | `cup` | cup-acme-prd-an2-app-user-01 |
| Cognito | 자격 증명 풀 (Identity Pool) | `cip` | cip-acme-prd-an2-web-auth-01 |

## A.7 Management, Governance (30)

| L0 | L2 리소스 | 약어 | Name 예시 |
|----|-----------|------|-----------|
| CloudWatch | 대시보드 | `cwdb` | cwdb-acme-prd-an2-main |
| CloudWatch | 경보 (Alarm) | `cwal` | cwal-acme-prd-an2-cpu-high-01 |
| CloudWatch 생성형 AI | 모델 간접 호출 감시 | `cwai` | cwai-acme-prd-an2-bedrock-01 |
| CloudWatch 생성형 AI | Bedrock AgentCore | `cwba` | cwba-acme-prd-an2-cs-helper-01 |
| CloudWatch App Signals | 서비스 수준 목표 (SLO) | `cwslo` | cwslo-acme-prd-an2-latency-std |
| CloudWatch App Signals | Synthetics Canary | `cwcy` | cwcy-acme-prd-an2-api-check-01 |
| CloudWatch App Signals | RUM App Monitor | `cwrm` | cwrm-acme-prd-an2-frontend-01 |
| CloudWatch 인프라 | Container Insights | `cwci` | cwci-acme-prd-an2-eks-main |
| CloudWatch 인프라 | Lambda Insights | `cwli` | cwli-acme-prd-an2-data-proc |
| CloudWatch 로그 | 로그 그룹 (Log Group) | `cwlg` | cwlg-acme-prd-an2-app-server |
| CloudWatch 로그 | 로그 분석 (Insights) | `cwlli` | cwlli-acme-prd-an2-error-check |
| CloudWatch 지표 | 메트릭 스트림 | `cwms` | cwms-acme-prd-an2-to-s3-01 |
| CloudWatch 네트워크 | 인터넷 모니터 | `cwim` | cwim-acme-prd-an2-global |
| CloudWatch 네트워크 | 흐름 모니터 (Flow) | `cwfm` | cwfm-acme-prd-an2-vpc-main |
| CloudTrail | 추적 (Trail) | `cttr` | cttr-acme-prd-an2-management-log |
| CloudTrail | 이벤트 데이터 스토어 | `ctds` | ctds-acme-prd-an2-security-anal-01 |
| CloudTrail | 통합 (Channel) | `ctch` | ctch-acme-prd-an2-external-audit |
| Config | 규정 준수 팩 | `cfgcp` | cfgcp-acme-prd-an2-nist-pack |
| Config | 규칙 (Rule) | `cfgr` | cfgr-acme-prd-an2-s3-public-check |
| Config | 애그리게이터 | `cfga` | cfga-acme-prd-an2-org-total |
| Config | 고급 쿼리 | `cfgaq` | cfgaq-acme-prd-an2-resource-inv |
| SSM | 세션 관리자 | `ssmsm` | ssmsm-acme-prd-an2-audit-log |
| SSM | 패치 관리자 | `ssmpm` | ssmpm-acme-prd-an2-linux-std |
| SSM | 상태 관리자 | `ssmst` | ssmst-acme-prd-an2-web-config |
| SSM | 자동화 (Automation) | `ssma` | ssma-acme-prd-an2-ec2-stop-start |
| SSM | 문서 (Document) | `ssmd` | ssmd-acme-prd-an2-harden-script |
| SSM | 파라미터 스토어 | `ssmps` | ssmps-acme-prd-an2-db-url |
| SSM | AppConfig | `ssmac` | ssmac-acme-prd-an2-feature-flag |
| CloudFormation | 스택 (Stack) | `cfns` | cfns-acme-prd-an2-network-base-01 |
| CloudFormation | StackSet | `cfnss` | cfnss-acme-prd-an2-security-std |

## A.8 Developer Tools, Others (31)

| L0 | L2 리소스 | 약어 | Name 예시 |
|----|-----------|------|-----------|
| CodeCommit | 리포지토리 | `ccr` | ccr-acme-prd-an2-webapp-01 |
| CodeCommit | 승인 규칙 템플릿 | `ccat` | ccat-acme-prd-an2-review-01 |
| CodeConnections | 연결 (Connection) | `ccon` | ccon-acme-prd-an2-gitops-01 |
| CodeBuild | 프로젝트 빌드 | `cbp` | cbp-acme-prd-an2-webbuild-01 |
| CodeBuild | 보고서 그룹 | `cbrg` | cbrg-acme-prd-an2-unittest-01 |
| CodeDeploy | 애플리케이션 | `cda` | cda-acme-prd-an2-web-svc-01 |
| CodeDeploy | 배포 구성 | `cdc` | cdc-acme-prd-an2-canary-std |
| CodePipeline | 파이프라인 | `cpn` | cpn-acme-prd-an2-web-01 |
| Step Functions | 상태 머신 | `sfsm` | sfsm-acme-prd-an2-order-01 |
| Step Functions | 활동 (Activity) | `sfact` | sfact-acme-prd-an2-manual-01 |
| Resilience Hub | 애플리케이션 | `rhapp` | rhapp-acme-prd-an2-svc-01 |
| Resilience Hub | 정책 (Policy) | `rhpol` | rhpol-acme-prd-an2-critical-01 |
| Resilience Hub | 실험 템플릿 | `rhet` | rhet-acme-prd-an2-fail-01 |
| Resilience Hub | 실험 (Experiment) | `rhex` | rhex-acme-prd-an2-test-01 |
| Prometheus | 워크스페이스 | `prow` | prow-acme-prd-an2-main-01 |
| Prometheus | 관리형 콜렉터 | `proc` | proc-acme-prd-an2-eks-01 |
| SNS | 주제 (Topic) | `snst` | snst-acme-prd-an2-alarm-01 |
| SNS | 구독 (Subscription) | `snss` | snss-acme-prd-an2-email-01 |
| SNS | 푸시 알림 | `snsp` | snsp-acme-prd-an2-push-01 |
| SQS | 대기열 (Queue) | `sqsq` | sqsq-acme-prd-an2-job-01 |
| EventBridge | 이벤트 버스 | `ebus` | ebus-acme-prd-an2-custom-01 |
| EventBridge | 규칙 (Rule) | `ebru` | ebru-acme-prd-an2-ec2-monitor-01 |
| EventBridge | 파이프 (Pipe) | `ebpp` | ebpp-acme-prd-an2-pipe-01 |
| EventBridge | 일정 (Schedule) | `ebsc` | ebsc-acme-prd-an2-dailytask-01 |
| EventBridge | 일정 그룹 | `ebsg` | ebsg-acme-prd-an2-batch-01 |
| EventBridge | 스키마 | `ebsk` | ebsk-acme-prd-an2-user-01 |
| DMS | 태스크 (Task) | `dmst` | dmst-acme-prd-an2-db-01 |
| DMS | 엔드포인트 | `dmse` | dmse-acme-prd-an2-src-01 |
| DMS | 복제 인스턴스 | `dmsi` | dmsi-acme-prd-an2-main-01 |
| DMS | 서브넷 그룹 | `dmsg` | dmsg-acme-prd-an2-main-01 |
| DMS | 데이터 수집기 | `dmsc` | dmsc-acme-prd-an2-ora-01 |

---

## 카테고리 카운트 요약

| # | 카테고리 | 약어 수 |
|---|----------|--------:|
| A.1 | Compute | 41 |
| A.2 | Network | 73 |
| A.3 | Databases | 39 |
| A.4 | Storage | 33 |
| A.5 | Analytics, AI, ML | 47 |
| A.6 | Security, Identity, Compliance | 18 |
| A.7 | Management, Governance | 30 |
| A.8 | Developer Tools, Others | 31 |
| | **합계** | **312** |

> ⚠️ **이 표는 2026-07-30에 정정됐다.** 그 전까지 합계 308(Network 72 · Security 16 · Developer Tools 30)로
> 남아 상단 서술·섹션 헤더와 어긋나 있었다 — `fl`·`iamp` 추가 시 갱신되지 않았고, Developer Tools의 1건은
> 개정 이력에도 없어 승계 원본부터의 불일치로 보인다. **실제 행을 세어**(카테고리별 약어 행 카운트)
> 섹션 헤더 쪽이 맞음을 확인한 뒤 이 표를 맞췄다. SSOT 문서에 총계가 두 개 있는 상태였으므로
> **약어를 추가할 때는 ① 섹션 헤더 ② 상단 총계 ③ 이 표를 함께 고친다.**
