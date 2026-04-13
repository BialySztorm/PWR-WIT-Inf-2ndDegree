Instrukcja: użycie istniejących IAM roles na kontach z ograniczonymi uprawnieniami (np. AWS Academy)

Jeżeli Twoje konto nie pozwala tworzyć ról IAM, musisz użyć istniejących ról. Poniżej opis kroków jak to zrobić przy pomocy AWS CLI i Terraform.

1) Wymagania:
- AWS CLI z poprawnym profilem (aws configure)
- Terraform

2) Znajdź istniejące Instance Profiles i Role w IAM (AWS CLI):

# Wylistuj wszystkie instance profiles
aws iam list-instance-profiles --query 'InstanceProfiles[].InstanceProfileName' --output text

# Wylistuj role (szukaj np. nazwy zawierającej 'elasticbeanstalk' lub 'eb')
aws iam list-roles --query 'Roles[?contains(RoleName, `elasticbeanstalk`) == `true`].RoleName' --output text

Przykładowe nazwy które często występują:
- aws-elasticbeanstalk-ec2-role (instance profile name)
- aws-elasticbeanstalk-service-role (service role name)

3) Zrób kopię pliku example i uzupełnij wartości:

# Skopiuj przykład
cp terraform.tfvars.example terraform.tfvars
# Edytuj terraform.tfvars i ustaw instance_profile_name i eb_service_role_name

4) Uruchom Terraform:

terraform init
terraform plan -out plan.tfplan
terraform apply "plan.tfplan"

5) Jeśli terraform nadal zgłasza błąd:
- Sprawdź uprawnienia Twojego profilu AWS (czy możesz odczytać IAM?)
- Sprawdź w konsoli IAM czy podane nazwy istnieją i czy są powiązane z odpowiednimi politykami (AWSElasticBeanstalkWebTier i AWSElasticBeanstalkService)

6) Jeżeli nie masz żadnych ról powiązanych z Elastic Beanstalk na koncie (bardzo rzadkie), poproś administratora utworzyć 2 role:
- Instance role name: (np. aws-elasticbeanstalk-ec2-role) z attached policy AWSElasticBeanstalkWebTier
- Service role name: (np. aws-elasticbeanstalk-service-role) z attached policy AWSElasticBeanstalkService


---

Jeżeli chcesz, mogę teraz:
- wygenerować gotowy `terraform.tfvars` (podaj nazwy roli i profilu albo pozwól, że pomogę znaleźć je przez AWS CLI),
- lub przeprowadzić symulację `terraform validate` tutaj (ale terraform nie jest zainstalowany w tym środowisku).
