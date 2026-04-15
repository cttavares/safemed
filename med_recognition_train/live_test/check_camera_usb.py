import cv2

def list_cameras():
    index = 0
    arr = []
    while index < 5: # Testa os primeiros 5 índices
        cap = cv2.VideoCapture(index)
        if cap.read()[0]:
            arr.append(index)
            cap.release()
        index += 1
    return arr

print(f"Câmaras detetadas nos índices: {list_cameras()}")