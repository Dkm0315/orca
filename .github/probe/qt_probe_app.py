import sys
try:
    from PyQt6.QtWidgets import QApplication, QGridLayout, QLineEdit, QPushButton, QWidget
except ImportError:
    from PyQt5.QtWidgets import QApplication, QGridLayout, QLineEdit, QPushButton, QWidget

app = QApplication(sys.argv)
app.setApplicationName("qtprobe")
window = QWidget()
window.setWindowTitle("Qt Probe")
layout = QGridLayout(window)
layout.addWidget(QLineEdit("hello"), 0, 0, 1, 3)
for index, label in enumerate(["Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Zeta"]):
    layout.addWidget(QPushButton(label), 1 + index // 3, index % 3)
window.resize(360, 200)
window.show()
sys.exit(app.exec())
