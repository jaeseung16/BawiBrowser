function LoginAutofill_EnableAutofill(id, current_password) {
    var login = document.getElementById("login_id");
    login.value = id;
    
    var password = document.getElementById("login_passwd");
    password.value = current_password
    
    return true
}
