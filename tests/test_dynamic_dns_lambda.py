import pytest
import pytest_mock
from v2.dynamic_dns_lambda import read_s3_config

def test_read_s3_config(mocker):
    mocker.patch('boto3.client.download_file')
    response = read_s3_config
    
    assert response.isinstance(dict)