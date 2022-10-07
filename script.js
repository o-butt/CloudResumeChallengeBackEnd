console.log('wow, such visitors.');


fetch('https://tomx98y9ib.execute-api.us-east-1.amazonaws.com/prod')
    .then(response => response.json())
    .then((data) => {
        document.getElementById('idgoeshere').innerText = data.count
    })