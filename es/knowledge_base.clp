(deftemplate vehicle
   (slot type (allowed-symbols car moto))
   (slot mileage (type INTEGER) (default 0))
   (slot battery-age (type INTEGER) (default -1)))

(deftemplate symptom
   (slot code))

(deftemplate symptom-info
   (slot code)
   (slot group)
   (slot text)
   (slot applies (allowed-symbols both car moto) (default both)))

(deftemplate fault-info
   (slot code)
   (slot name)
   (slot severity (allowed-symbols low medium high critical))
   (slot advice))

(deftemplate part
   (slot fault)
   (slot name)
   (slot category)
   (slot vehicle (allowed-symbols both car moto) (default both)))

(deftemplate evidence
   (slot fault)
   (slot cf (type FLOAT))
   (slot rule)
   (slot text)
   (slot used (default no)))

(deftemplate fault
   (slot code)
   (slot cf (type FLOAT)))

(deftemplate recommendation (slot fault) (slot part) (slot category))
(deftemplate warning (slot fault) (slot text))
(deftemplate conclusion (slot text))

(deffunction combine-cf (?a ?b)
   (if (and (>= ?a 0.0) (>= ?b 0.0))
      then (+ ?a (* ?b (- 1.0 ?a)))
      else (if (and (< ?a 0.0) (< ?b 0.0))
              then (+ ?a (* ?b (+ 1.0 ?a)))
              else (/ (+ ?a ?b) (- 1.0 (min (abs ?a) (abs ?b)))))))

(defglobal ?*threshold* = 0.4)

(deffacts symptoms

   (symptom-info (code no-start)        (group "Пуск и электрооборудование") (text "Двигатель не заводится"))
   (symptom-info (code starter-clicks)  (group "Пуск и электрооборудование") (text "Стартер щёлкает, но не прокручивает двигатель"))
   (symptom-info (code slow-crank)      (group "Пуск и электрооборудование") (text "Стартер крутит вяло, с трудом"))
   (symptom-info (code silent-crank)    (group "Пуск и электрооборудование") (text "При повороте ключа (нажатии кнопки) - тишина"))
   (symptom-info (code dim-lights)      (group "Пуск и электрооборудование") (text "Фары и приборы светят тускло"))
   (symptom-info (code battery-light)   (group "Пуск и электрооборудование") (text "Горит лампа заряда АКБ при работающем двигателе"))
   (symptom-info (code cold-weather)    (group "Пуск и электрооборудование") (text "Проблема проявляется в мороз (ниже -15 градусов)"))
   (symptom-info (code belt-squeal)     (group "Пуск и электрооборудование") (text "Свист из-под капота при запуске или включении нагрузки") (applies car))

   (symptom-info (code rough-idle)      (group "Двигатель") (text "Неустойчивый холостой ход, троение"))
   (symptom-info (code check-engine)    (group "Двигатель") (text "Горит индикатор Check Engine"))
   (symptom-info (code power-loss)      (group "Двигатель") (text "Потеря мощности, вялый разгон"))
   (symptom-info (code high-fuel)       (group "Двигатель") (text "Повышенный расход топлива"))
   (symptom-info (code black-smoke)     (group "Двигатель") (text "Чёрный дым из выхлопной трубы"))
   (symptom-info (code blue-smoke)      (group "Двигатель") (text "Сизый (голубоватый) дым из выхлопной трубы"))
   (symptom-info (code oil-consumption) (group "Двигатель") (text "Приходится доливать масло между заменами"))
   (symptom-info (code white-smoke)     (group "Двигатель") (text "Густой белый дым со сладковатым запахом"))
   (symptom-info (code overheat)        (group "Двигатель") (text "Перегрев: стрелка температуры в красной зоне"))
   (symptom-info (code coolant-loss)    (group "Двигатель") (text "Уходит охлаждающая жидкость"))
   (symptom-info (code no-cabin-heat)   (group "Двигатель") (text "Печка дует холодным на прогретом двигателе") (applies car))

   (symptom-info (code brake-squeal)    (group "Тормозная система") (text "Скрип или металлический визг при торможении"))
   (symptom-info (code brake-soft)      (group "Тормозная система") (text "Педаль (рычаг) тормоза мягкая, проваливается"))
   (symptom-info (code brake-fluid-low) (group "Тормозная система") (text "Уровень тормозной жидкости ниже метки MIN"))
   (symptom-info (code brake-vibration) (group "Тормозная система") (text "Биение руля или педали при торможении"))
   (symptom-info (code brake-pull)      (group "Тормозная система") (text "Автомобиль уводит в сторону при торможении") (applies car))
   (symptom-info (code wheel-hot)       (group "Тормозная система") (text "Один колёсный диск сильно нагревается после поездки"))

   (symptom-info (code knock-bumps)     (group "Ходовая часть и трансмиссия") (text "Стук в подвеске на неровностях"))
   (symptom-info (code bounce)          (group "Ходовая часть и трансмиссия") (text "Раскачка после неровности, 'пробои' подвески"))
   (symptom-info (code oil-on-shock)    (group "Ходовая часть и трансмиссия") (text "Масляные подтёки на амортизаторе или пере вилки"))
   (symptom-info (code chain-noise)     (group "Ходовая часть и трансмиссия") (text "Шум, рывки или провисание приводной цепи") (applies moto))
   (symptom-info (code clutch-slip)     (group "Ходовая часть и трансмиссия") (text "Обороты растут, а скорость нет (пробуксовка сцепления)"))
   (symptom-info (code clutch-high)     (group "Ходовая часть и трансмиссия") (text "Сцепление 'схватывает' в самом конце хода педали (рычага)")))

(deffacts faults
   (fault-info (code battery) (name "Разряд или износ аккумуляторной батареи") (severity medium)
      (advice "Проверьте напряжение АКБ мультиметром: менее 12,4 В - зарядить, после зарядки менее 12,6 В или возраст более 4 лет - заменить."))
   (fault-info (code starter) (name "Неисправность стартера или втягивающего реле") (severity medium)
      (advice "Проверьте контакты и массу стартера; при исправной АКБ замените втягивающее реле или стартер в сборе."))
   (fault-info (code alternator) (name "Неисправность генератора или реле-регулятора") (severity high)
      (advice "Измерьте напряжение на работающем двигателе: норма 13,8-14,5 В. Ниже нормы - генератор/регулятор, АКБ разряжается в движении."))
   (fault-info (code belt) (name "Износ или ослабление приводного ремня") (severity medium)
      (advice "Осмотрите ремень на трещины и расслоение, проверьте натяжитель. Обрыв ремня отключает генератор (и помпу на ряде моторов)."))
   (fault-info (code ignition) (name "Неисправность системы зажигания (свечи, катушки)") (severity medium)
      (advice "Выкрутите свечи и оцените нагар и зазор; при пропусках по одному цилиндру поменяйте катушки местами, чтобы найти неисправную."))
   (fault-info (code fuel) (name "Неисправность топливной системы (фильтр, насос, форсунки)") (severity medium)
      (advice "Проверьте давление топлива и работу насоса при включении зажигания; топливный фильтр меняйте по регламенту."))
   (fault-info (code air-intake) (name "Переобогащение смеси: воздушный фильтр, ДМРВ, лямбда-зонд") (severity low)
      (advice "Замените воздушный фильтр; если признаки сохранятся - считайте ошибки ЭБУ и проверьте датчики ДМРВ и лямбда-зонд."))
   (fault-info (code oil-burning) (name "Угар масла: износ маслосъёмных колпачков или колец") (severity high)
      (advice "Замерьте компрессию и расход масла на 1000 км. Дым при пуске указывает на колпачки, постоянный дым под нагрузкой - на кольца."))
   (fault-info (code head-gasket) (name "Пробой прокладки ГБЦ") (severity critical)
      (advice "Прекратите эксплуатацию! Проверьте масло на эмульсию и расширительный бачок на пузыри газов. Требуется замена прокладки и проверка плоскости ГБЦ."))
   (fault-info (code cooling) (name "Неисправность системы охлаждения (термостат, помпа, вентилятор, утечка)") (severity critical)
      (advice "Не продолжайте движение при перегреве. Проверьте уровень ОЖ, герметичность патрубков, работу термостата и вентилятора."))
   (fault-info (code brake-pads) (name "Износ тормозных колодок") (severity medium)
      (advice "Проверьте толщину накладок: менее 2-3 мм - замена колодок на оси (комплектом с обеих сторон)."))
   (fault-info (code brake-discs) (name "Коробление или износ тормозных дисков") (severity medium)
      (advice "Замерьте толщину и биение дисков. Диски меняются парой на оси вместе с новыми колодками."))
   (fault-info (code brake-hydraulics) (name "Утечка или завоздушивание гидропривода тормозов") (severity critical)
      (advice "Эксплуатация опасна! Найдите место утечки (шланги, цилиндры, суппорты), замените тормозную жидкость и прокачайте систему."))
   (fault-info (code brake-caliper) (name "Закисание тормозного суппорта") (severity high)
      (advice "Переберите суппорт: очистите и смажьте направляющие, замените пыльники и манжету поршня."))
   (fault-info (code shocks) (name "Износ амортизаторов (передней вилки)") (severity medium)
      (advice "Амортизаторы меняются парой на оси. У мотоцикла - замена сальников и масла вилки."))
   (fault-info (code suspension-joints) (name "Износ элементов подвески (стойки стабилизатора, сайлентблоки, шаровые)") (severity medium)
      (advice "Проверьте люфты на подъёмнике монтировкой; чаще всего стучат стойки стабилизатора."))
   (fault-info (code chain) (name "Растяжение приводной цепи и износ звёзд") (severity high)
      (advice "Цепь и звёзды меняются комплектом. Проверьте натяжение: провис 25-35 мм по центру нижней ветви."))
   (fault-info (code clutch) (name "Износ сцепления") (severity medium)
      (advice "Проверьте свободный ход педали (рычага) и привод. При пробуксовке замените комплект сцепления.")))

(deffacts catalog
   (part (fault battery) (name "Аккумуляторная батарея") (category "Электрооборудование / АКБ"))
   (part (fault battery) (name "Клеммы аккумулятора") (category "Электрооборудование / Клеммы и провода"))
   (part (fault battery) (name "Зарядное устройство для АКБ") (category "Инструмент / Зарядные устройства"))
   (part (fault starter) (name "Втягивающее реле стартера") (category "Электрооборудование / Стартеры"))
   (part (fault starter) (name "Стартер в сборе") (category "Электрооборудование / Стартеры"))
   (part (fault alternator) (name "Генератор в сборе") (category "Электрооборудование / Генераторы") (vehicle car))
   (part (fault alternator) (name "Диодный мост генератора") (category "Электрооборудование / Генераторы") (vehicle car))
   (part (fault alternator) (name "Реле-регулятор напряжения") (category "Электрооборудование / Генераторы"))
   (part (fault alternator) (name "Статор генератора") (category "Мотозапчасти / Электрика") (vehicle moto))
   (part (fault belt) (name "Поликлиновой приводной ремень") (category "Двигатель / Ремни и ролики") (vehicle car))
   (part (fault belt) (name "Натяжной ролик приводного ремня") (category "Двигатель / Ремни и ролики") (vehicle car))
   (part (fault ignition) (name "Свечи зажигания") (category "Двигатель / Система зажигания"))
   (part (fault ignition) (name "Катушка зажигания") (category "Двигатель / Система зажигания"))
   (part (fault ignition) (name "Высоковольтные провода") (category "Двигатель / Система зажигания") (vehicle car))
   (part (fault fuel) (name "Топливный фильтр") (category "Фильтры / Топливные"))
   (part (fault fuel) (name "Топливный насос") (category "Двигатель / Топливная система"))
   (part (fault fuel) (name "Очиститель форсунок и карбюратора") (category "Автохимия / Присадки"))
   (part (fault air-intake) (name "Воздушный фильтр") (category "Фильтры / Воздушные"))
   (part (fault air-intake) (name "Датчик массового расхода воздуха (ДМРВ)") (category "Электрооборудование / Датчики") (vehicle car))
   (part (fault air-intake) (name "Лямбда-зонд") (category "Электрооборудование / Датчики"))
   (part (fault oil-burning) (name "Маслосъёмные колпачки") (category "Двигатель / Ремкомплекты ГБЦ"))
   (part (fault oil-burning) (name "Комплект поршневых колец") (category "Двигатель / Поршневая группа"))
   (part (fault oil-burning) (name "Моторное масло") (category "Масла и жидкости / Моторные масла"))
   (part (fault head-gasket) (name "Прокладка ГБЦ") (category "Двигатель / Прокладки"))
   (part (fault head-gasket) (name "Болты ГБЦ") (category "Двигатель / Крепёж"))
   (part (fault head-gasket) (name "Охлаждающая жидкость (антифриз)") (category "Масла и жидкости / Антифризы"))
   (part (fault cooling) (name "Термостат") (category "Система охлаждения / Термостаты"))
   (part (fault cooling) (name "Помпа (водяной насос)") (category "Система охлаждения / Помпы"))
   (part (fault cooling) (name "Датчик включения вентилятора") (category "Система охлаждения / Вентиляторы и датчики"))
   (part (fault cooling) (name "Патрубки системы охлаждения") (category "Система охлаждения / Патрубки"))
   (part (fault cooling) (name "Охлаждающая жидкость (антифриз)") (category "Масла и жидкости / Антифризы"))
   (part (fault brake-pads) (name "Тормозные колодки") (category "Тормозная система / Колодки"))
   (part (fault brake-pads) (name "Датчик износа колодок") (category "Тормозная система / Колодки") (vehicle car))
   (part (fault brake-discs) (name "Тормозные диски") (category "Тормозная система / Диски"))
   (part (fault brake-discs) (name "Тормозные колодки") (category "Тормозная система / Колодки"))
   (part (fault brake-hydraulics) (name "Тормозная жидкость DOT 4") (category "Масла и жидкости / Тормозные жидкости"))
   (part (fault brake-hydraulics) (name "Тормозные шланги") (category "Тормозная система / Шланги"))
   (part (fault brake-hydraulics) (name "Ремкомплект главного тормозного цилиндра") (category "Тормозная система / Цилиндры"))
   (part (fault brake-caliper) (name "Ремкомплект суппорта") (category "Тормозная система / Суппорты"))
   (part (fault brake-caliper) (name "Направляющие суппорта") (category "Тормозная система / Суппорты"))
   (part (fault brake-caliper) (name "Смазка для направляющих суппорта") (category "Автохимия / Смазки"))
   (part (fault shocks) (name "Амортизаторы (пара)") (category "Подвеска / Амортизаторы") (vehicle car))
   (part (fault shocks) (name "Пыльники и отбойники амортизаторов") (category "Подвеска / Амортизаторы") (vehicle car))
   (part (fault shocks) (name "Сальники вилки") (category "Мотозапчасти / Подвеска") (vehicle moto))
   (part (fault shocks) (name "Масло для вилки") (category "Масла и жидкости / Мотохимия") (vehicle moto))
   (part (fault shocks) (name "Задний амортизатор") (category "Мотозапчасти / Подвеска") (vehicle moto))
   (part (fault suspension-joints) (name "Стойки стабилизатора") (category "Подвеска / Рычаги и тяги") (vehicle car))
   (part (fault suspension-joints) (name "Сайлентблоки рычагов") (category "Подвеска / Сайлентблоки") (vehicle car))
   (part (fault suspension-joints) (name "Шаровые опоры") (category "Подвеска / Рычаги и тяги") (vehicle car))
   (part (fault suspension-joints) (name "Подшипники рулевой колонки") (category "Мотозапчасти / Рулевое управление") (vehicle moto))
   (part (fault suspension-joints) (name "Подшипники маятника") (category "Мотозапчасти / Подвеска") (vehicle moto))
   (part (fault chain) (name "Приводная цепь") (category "Мотозапчасти / Трансмиссия") (vehicle moto))
   (part (fault chain) (name "Комплект звёзд") (category "Мотозапчасти / Трансмиссия") (vehicle moto))
   (part (fault chain) (name "Смазка для цепи") (category "Масла и жидкости / Мотохимия") (vehicle moto))
   (part (fault clutch) (name "Комплект сцепления (корзина, диск, выжимной)") (category "Трансмиссия / Сцепление") (vehicle car))
   (part (fault clutch) (name "Фрикционные диски сцепления") (category "Мотозапчасти / Сцепление") (vehicle moto))
   (part (fault clutch) (name "Пружины сцепления") (category "Мотозапчасти / Сцепление") (vehicle moto))
   (part (fault clutch) (name "Трос сцепления") (category "Мотозапчасти / Сцепление") (vehicle moto)))

(defrule bat-slow-crank (declare (salience 10))
   (symptom (code slow-crank))
   =>
   (assert (evidence (fault battery) (cf 0.6) (rule bat-slow-crank)
      (text "Стартер крутит вяло - стартеру не хватает тока, типичный признак разряженной АКБ"))))

(defrule bat-clicks-dim (declare (salience 10))
   (symptom (code starter-clicks))
   (symptom (code dim-lights))
   =>
   (assert (evidence (fault battery) (cf 0.7) (rule bat-clicks-dim)
      (text "Стартер щёлкает и при этом тускнеет свет - напряжение АКБ 'проседает' под нагрузкой"))))

(defrule bat-nostart-dim (declare (salience 10))
   (symptom (code no-start))
   (symptom (code dim-lights))
   =>
   (assert (evidence (fault battery) (cf 0.6) (rule bat-nostart-dim)
      (text "Двигатель не заводится и свет тусклый - АКБ разряжена"))))

(defrule bat-cold (declare (salience 10))
   (symptom (code cold-weather))
   (exists (symptom (code no-start|slow-crank|starter-clicks)))
   =>
   (assert (evidence (fault battery) (cf 0.4) (rule bat-cold)
      (text "Проблемы с пуском на морозе: ёмкость АКБ при -20 градусах падает почти вдвое"))))

(defrule bat-old (declare (salience 10))
   (vehicle (battery-age ?a&:(>= ?a 4)))
   (exists (symptom (code no-start|slow-crank|starter-clicks)))
   =>
   (assert (evidence (fault battery) (cf 0.4) (rule bat-old)
      (text (str-cat "Возраст АКБ " ?a " лет при среднем сроке службы 3-5 лет")))))

(defrule bat-new (declare (salience 10))
   (vehicle (battery-age ?a&:(and (>= ?a 0) (<= ?a 1))))
   (exists (symptom (code no-start|slow-crank|starter-clicks)))
   =>
   (assert (evidence (fault battery) (cf -0.3) (rule bat-new)
      (text "АКБ новая (до 1 года) - вероятность её износа ниже"))))

(defrule starter-clicks-bright (declare (salience 10))
   (symptom (code starter-clicks))
   (not (symptom (code dim-lights)))
   =>
   (assert (evidence (fault starter) (cf 0.7) (rule starter-clicks-bright)
      (text "Стартер щёлкает при нормальном свете - АКБ отдаёт ток, неисправно втягивающее реле или стартер"))))

(defrule starter-silent (declare (salience 10))
   (symptom (code silent-crank))
   (not (symptom (code dim-lights)))
   =>
   (assert (evidence (fault starter) (cf 0.6) (rule starter-silent)
      (text "Стартер не реагирует при исправном освещении - обрыв цепи управления или реле стартера"))))

(defrule alt-battery-light (declare (salience 10))
   (symptom (code battery-light))
   =>
   (assert (evidence (fault alternator) (cf 0.7) (rule alt-battery-light)
      (text "Лампа заряда горит на работающем двигателе - генератор не заряжает АКБ"))))

(defrule alt-dim-running (declare (salience 10))
   (symptom (code battery-light))
   (symptom (code dim-lights))
   =>
   (assert (evidence (fault alternator) (cf 0.3) (rule alt-dim-running)
      (text "Тусклый свет вместе с лампой заряда - бортовая сеть питается только от АКБ"))))

(defrule belt-squeal (declare (salience 10))
   (vehicle (type car))
   (symptom (code belt-squeal))
   =>
   (assert (evidence (fault belt) (cf 0.8) (rule belt-squeal)
      (text "Свист при запуске и под нагрузкой - проскальзывание приводного ремня"))))

(defrule belt-and-charge (declare (salience 10))
   (vehicle (type car))
   (symptom (code belt-squeal))
   (symptom (code battery-light))
   =>
   (assert (evidence (fault belt) (cf 0.3) (rule belt-and-charge)
      (text "Свист ремня и лампа заряда - проскальзывающий ремень недокручивает генератор"))))

(defrule ign-rough-check (declare (salience 10))
   (symptom (code rough-idle))
   (symptom (code check-engine))
   =>
   (assert (evidence (fault ignition) (cf 0.6) (rule ign-rough-check)
      (text "Троение с индикатором Check Engine - ЭБУ фиксирует пропуски воспламенения"))))

(defrule ign-rough-power (declare (salience 10))
   (symptom (code rough-idle))
   (symptom (code power-loss))
   =>
   (assert (evidence (fault ignition) (cf 0.4) (rule ign-rough-power)
      (text "Троение и потеря мощности - один из цилиндров не работает"))))

(defrule ign-mileage (declare (salience 10))
   (vehicle (mileage ?m&:(>= ?m 60000)))
   (symptom (code rough-idle))
   =>
   (assert (evidence (fault ignition) (cf 0.3) (rule ign-mileage)
      (text "Пробег более 60 000 км - свечи зажигания, вероятно, выработали ресурс"))))

(defrule ign-nostart-normal-crank (declare (salience 10))
   (symptom (code no-start))
   (not (symptom (code slow-crank|starter-clicks|silent-crank|dim-lights)))
   =>
   (assert (evidence (fault ignition) (cf 0.4) (rule ign-nostart-normal-crank)
      (text "Стартер крутит нормально, но пуска нет - нет искры или топлива"))))

(defrule fuel-nostart-normal-crank (declare (salience 10))
   (symptom (code no-start))
   (not (symptom (code slow-crank|starter-clicks|silent-crank|dim-lights)))
   =>
   (assert (evidence (fault fuel) (cf 0.4) (rule fuel-nostart-normal-crank)
      (text "Стартер крутит нормально, но пуска нет - проверьте подачу топлива"))))

(defrule fuel-power-loss (declare (salience 10))
   (symptom (code power-loss))
   (not (symptom (code rough-idle)))
   =>
   (assert (evidence (fault fuel) (cf 0.5) (rule fuel-power-loss)
      (text "Ровная работа, но вялый разгон - двигателю не хватает топлива (фильтр, насос)"))))

(defrule air-black-smoke (declare (salience 10))
   (symptom (code black-smoke))
   =>
   (assert (evidence (fault air-intake) (cf 0.6) (rule air-black-smoke)
      (text "Чёрный дым - несгоревшее топливо, смесь переобогащена"))))

(defrule air-high-fuel (declare (salience 10))
   (symptom (code high-fuel))
   (exists (symptom (code black-smoke|check-engine)))
   =>
   (assert (evidence (fault air-intake) (cf 0.4) (rule air-high-fuel)
      (text "Повышенный расход вместе с дымом или Check Engine - неверно дозируется смесь"))))

(defrule oil-blue-smoke (declare (salience 10))
   (symptom (code blue-smoke))
   =>
   (assert (evidence (fault oil-burning) (cf 0.6) (rule oil-blue-smoke)
      (text "Сизый дым - в цилиндрах сгорает моторное масло"))))

(defrule oil-consumption (declare (salience 10))
   (symptom (code oil-consumption))
   =>
   (assert (evidence (fault oil-burning) (cf 0.5) (rule oil-consumption)
      (text "Повышенный расход масла"))))

(defrule oil-high-mileage (declare (salience 10))
   (or (vehicle (type car)  (mileage ?m&:(>= ?m 150000)))
       (vehicle (type moto) (mileage ?m&:(>= ?m 50000))))
   (exists (symptom (code blue-smoke|oil-consumption)))
   =>
   (assert (evidence (fault oil-burning) (cf 0.3) (rule oil-high-mileage)
      (text (str-cat "Пробег " ?m " км - естественный износ цилиндропоршневой группы")))))

(defrule hg-smoke-coolant (declare (salience 10))
   (symptom (code white-smoke))
   (symptom (code coolant-loss))
   =>
   (assert (evidence (fault head-gasket) (cf 0.8) (rule hg-smoke-coolant)
      (text "Белый сладкий дым при уходе антифриза - ОЖ попадает в цилиндры"))))

(defrule hg-smoke-overheat (declare (salience 10))
   (symptom (code white-smoke))
   (symptom (code overheat))
   =>
   (assert (evidence (fault head-gasket) (cf 0.5) (rule hg-smoke-overheat)
      (text "Белый дым после перегрева - перегрев часто приводит к пробою прокладки"))))

(defrule hg-smoke-only (declare (salience 10))
   (symptom (code white-smoke))
   =>
   (assert (evidence (fault head-gasket) (cf 0.3) (rule hg-smoke-only)
      (text "Густой белый дым со сладким запахом"))))

(defrule hg-cold-condensate (declare (salience 10))
   (symptom (code white-smoke))
   (symptom (code cold-weather))
   (not (symptom (code coolant-loss|overheat)))
   =>
   (assert (evidence (fault head-gasket) (cf -0.5) (rule hg-cold-condensate)
      (text "В мороз белый пар из выхлопа - обычно конденсат, а уровень ОЖ не падает"))))

(defrule cool-overheat (declare (salience 10))
   (symptom (code overheat))
   =>
   (assert (evidence (fault cooling) (cf 0.6) (rule cool-overheat)
      (text "Перегрев двигателя - система охлаждения не отводит тепло"))))

(defrule cool-no-heat (declare (salience 10))
   (symptom (code overheat))
   (symptom (code no-cabin-heat))
   =>
   (assert (evidence (fault cooling) (cf 0.4) (rule cool-no-heat)
      (text "Перегрев и холодная печка - ОЖ не циркулирует (помпа, воздушная пробка, низкий уровень)"))))

(defrule cool-leak (declare (salience 10))
   (symptom (code coolant-loss))
   (not (symptom (code white-smoke)))
   =>
   (assert (evidence (fault cooling) (cf 0.6) (rule cool-leak)
      (text "Уходит ОЖ без белого дыма - внешняя утечка (патрубки, радиатор, помпа)"))))

(defrule brk-squeal (declare (salience 10))
   (symptom (code brake-squeal))
   =>
   (assert (evidence (fault brake-pads) (cf 0.6) (rule brk-squeal)
      (text "Скрип при торможении - сработал индикатор износа колодок"))))

(defrule brk-squeal-fluid (declare (salience 10))
   (symptom (code brake-squeal))
   (symptom (code brake-fluid-low))
   =>
   (assert (evidence (fault brake-pads) (cf 0.4) (rule brk-squeal-fluid)
      (text "Уровень тормозной жидкости падает по мере износа колодок (поршни выдвигаются)"))))

(defrule brk-vibration (declare (salience 10))
   (symptom (code brake-vibration))
   =>
   (assert (evidence (fault brake-discs) (cf 0.7) (rule brk-vibration)
      (text "Биение при торможении - диск покороблен, его толщина неравномерна"))))

(defrule brk-soft (declare (salience 10))
   (symptom (code brake-soft))
   =>
   (assert (evidence (fault brake-hydraulics) (cf 0.7) (rule brk-soft)
      (text "Мягкая педаль (рычаг) - в гидроприводе воздух или утечка жидкости"))))

(defrule brk-soft-fluid (declare (salience 10))
   (symptom (code brake-soft))
   (symptom (code brake-fluid-low))
   =>
   (assert (evidence (fault brake-hydraulics) (cf 0.5) (rule brk-soft-fluid)
      (text "Мягкая педаль и низкий уровень жидкости - утечка из гидропривода"))))

(defrule brk-fluid-only (declare (salience 10))
   (symptom (code brake-fluid-low))
   (not (symptom (code brake-squeal|brake-soft)))
   =>
   (assert (evidence (fault brake-hydraulics) (cf 0.4) (rule brk-fluid-only)
      (text "Уровень жидкости упал без признаков износа колодок - возможна утечка"))))

(defrule brk-hot-wheel (declare (salience 10))
   (symptom (code wheel-hot))
   =>
   (assert (evidence (fault brake-caliper) (cf 0.7) (rule brk-hot-wheel)
      (text "Одно колесо греется - колодки постоянно поджаты закисшим суппортом"))))

(defrule brk-pull (declare (salience 10))
   (vehicle (type car))
   (symptom (code brake-pull))
   =>
   (assert (evidence (fault brake-caliper) (cf 0.5) (rule brk-pull)
      (text "Увод при торможении - тормозные механизмы правой и левой стороны работают неодинаково"))))

(defrule susp-bounce (declare (salience 10))
   (symptom (code bounce))
   =>
   (assert (evidence (fault shocks) (cf 0.7) (rule susp-bounce)
      (text "Раскачка после неровности - амортизатор не гасит колебания"))))

(defrule susp-oil (declare (salience 10))
   (symptom (code oil-on-shock))
   =>
   (assert (evidence (fault shocks) (cf 0.7) (rule susp-oil)
      (text "Масляные подтёки - амортизатор (сальник вилки) потерял герметичность"))))

(defrule susp-knock (declare (salience 10))
   (symptom (code knock-bumps))
   =>
   (assert (evidence (fault suspension-joints) (cf 0.6) (rule susp-knock)
      (text "Стук на неровностях - люфт в шарнирах подвески"))))

(defrule susp-knock-bounce (declare (salience 10))
   (symptom (code knock-bumps))
   (symptom (code bounce))
   =>
   (assert (evidence (fault shocks) (cf 0.3) (rule susp-knock-bounce)
      (text "Стук вместе с раскачкой - 'пробои' изношенного амортизатора"))))

(defrule chain-noise (declare (salience 10))
   (vehicle (type moto))
   (symptom (code chain-noise))
   =>
   (assert (evidence (fault chain) (cf 0.8) (rule chain-noise)
      (text "Шум и рывки цепи - цепь растянута, звёзды изношены"))))

(defrule chain-mileage (declare (salience 10))
   (vehicle (type moto) (mileage ?m&:(>= ?m 20000)))
   (symptom (code chain-noise))
   =>
   (assert (evidence (fault chain) (cf 0.3) (rule chain-mileage)
      (text "Пробег более 20 000 км - средний ресурс цепного комплекта"))))

(defrule clutch-slip (declare (salience 10))
   (symptom (code clutch-slip))
   =>
   (assert (evidence (fault clutch) (cf 0.8) (rule clutch-slip)
      (text "Пробуксовка: обороты растут, скорость нет - изношены фрикционные накладки"))))

(defrule clutch-high (declare (salience 10))
   (symptom (code clutch-high))
   =>
   (assert (evidence (fault clutch) (cf 0.5) (rule clutch-high)
      (text "Сцепление схватывает в конце хода - диск сцепления изношен"))))

(defrule cf-new-hypothesis (declare (salience 5))
   ?e <- (evidence (fault ?f) (cf ?c) (used no))
   (not (fault (code ?f)))
   =>
   (modify ?e (used yes))
   (assert (fault (code ?f) (cf ?c))))

(defrule cf-combine (declare (salience 5))
   ?e <- (evidence (fault ?f) (cf ?c) (used no))
   ?h <- (fault (code ?f) (cf ?old))
   =>
   (modify ?e (used yes))
   (modify ?h (cf (combine-cf ?old ?c))))

(defrule recommend-parts
   (fault (code ?f) (cf ?cf&:(>= ?cf ?*threshold*)))
   (vehicle (type ?t))
   (part (fault ?f) (name ?n) (category ?c) (vehicle ?v&:(or (eq ?v both) (eq ?v ?t))))
   =>
   (assert (recommendation (fault ?f) (part ?n) (category ?c))))

(defrule critical-warning
   (fault (code ?f) (cf ?cf&:(>= ?cf ?*threshold*)))
   (fault-info (code ?f) (severity critical) (name ?n))
   =>
   (assert (warning (fault ?f)
      (text (str-cat "Вероятна критическая неисправность: " ?n ". Эксплуатация транспортного средства опасна до устранения.")))))

(defrule no-diagnosis (declare (salience -10))
   (not (fault (cf ?cf&:(>= ?cf ?*threshold*))))
   =>
   (assert (conclusion (text "Достоверный диагноз не установлен: введённых симптомов недостаточно. Рекомендуется компьютерная диагностика на СТО."))))
