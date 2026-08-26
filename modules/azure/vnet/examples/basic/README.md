# vnet basic 예제

**읽는 사람**: `vnet` 모듈을 처음 써보려는 사람.

리소스 그룹과 vnet을 한 apply에서 세우는 최소 착수 템플릿이다. 그룹 2개(`app`은 NAT·NSG·라우팅
테이블 전부 켬, `data`는 NAT·NSG만)로 옵트인 조합을 보여준다.

소비 프로젝트는 상대경로가 아니라 git tag로 소싱한다(모듈 [`README.md`](../../README.md) 참조).
계약 검증(교차변수 validation 등)은 이 예제가 아니라 [`tests/`](../../tests/)가 한다. 이 예제는
`tofu validate`까지만 돈다.
