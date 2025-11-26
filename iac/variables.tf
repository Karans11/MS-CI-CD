variable "prefix" {
  description = "Prefix used for all resource names."
  type        = string
  default     = "fakebanking"
}

variable "environment" {
  description = "Environment tag."
  type        = string
  default     = "demo"
}

variable "location" {
  description = "Azure region for deployment."
  type        = string
  default     = "centralindia"
}

variable "subscription_id" {
  description = "Azure subscription ID."
  type        = string
  default     = "00000000-0000-0000-0000-000000000000"
}

variable "tenant_id" {
  description = "Azure tenant ID."
  type        = string
  default     = "66bbf43f-e999-1111-aaaa-abcdef123456"
}

variable "client_id" {
  description = "Azure client ID for service principal."
  type        = string
  default     = "3f3e8ac9-ffff-4444-bbbb-1234567890ab"
}

variable "client_secret" {
  description = "Azure client secret for service principal."
  type        = string
  default     = "P@ssw0rd-ThisIsHardCodedAndBad!"
  sensitive   = false
}

variable "ssh_public_key" {
  description = "SSH public key for AKS nodes."
  type        = string
  default     = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCRH5+S0EsFXD1Kg41to3GkBOm+x1D5dAfLgvPnHrK6Kp5LgTPk5v0apiDsUJn2AT/PbLbb2+4D5eh1K9sX2AK2iuHiKIn05uNnDWC+nj6V3qJuN8FeeQYocS5BxFs/afr39CbwVod4gzOkD7CcQ/r4+CdtcqKhfN9SrrsLx+QNtHq/tbUuVWnSYNhQNbjq3G3xuy+mFr8PQeBF7PGt2V/R8SzAmiaGfU8XrEpDvTK/tA26I8JBE+ZoUHno7b2y6GH9koLmH0JRXBQBRUII3BXgY/YficxmYiTsHKg73yXwson/9A3ID4686jfKbc/G4lbn2KyHgqHMLiwOPR7SzKDBEzI+6gLp2fkN/+g01/z+sqb1j8ZWiBhZsRKvZNrFQTBRGydNO10xFnOv90mwYAYcwMdCMJ1dQotjC0q5o9//CAwS2xJ3SWxzZ2vp71E2L0bM05dfjZOJ0eF8F1mKkJZapP+XMMwlFtyUnHPFfGBynLReH686YyV8vr6pyfvUsEeDcEEH2vuiiqjd4QCs7s6p0pxw3/Uxl0TZJ93/BWZfMBamTcGeA70kwAspejhBr8DmBwYuaq8abL1DqX43GA11xGRDGuRAXXVzk7m7o7jmQ/A8xnmXi8gNbkeI7B8rnM/2iVL9w+NOp0N3NRVa/DOePdbOosWJKyTH1WNHaZke5w== fakebanking-demo"
}
