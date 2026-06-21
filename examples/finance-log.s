skill balance(income, expenses) {
    out income - expenses
}

program() {
    @income = 112000
    @expenses = 33200
    @total = balance(income, expenses)
    host.io.println("balance: ", total)
    out none
}
