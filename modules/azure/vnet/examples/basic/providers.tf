# Azure는 provider 한 곳에서 거버넌스 태그를 자동 주입할 수단이 없다(azurerm에 default_tags
# 대응 인자 없음, docs/conventions.md Azure 강제 방식 1번). 소비 프로젝트는 리소스마다 tags를
# 명시로 배선한다. 이 모듈이 만드는 NSG·라우팅 테이블에 var.tags를 넘기는 것이 그 배선이다.
provider "azurerm" {
  features {}
}
