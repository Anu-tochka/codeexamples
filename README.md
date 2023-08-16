1. Сложная форма
   Форма, которая собирает информацию сразу по нескольким сотрудникам и отправляет одной кнопкой (в базу будет записано несколько строк). Стандартная форма Symfony не используется.

Вывод формы в шаблоне:   
<form method="post" id="tableform" class="ajax_form" action="" enctype="multipart/form-data">
<table> 
<caption>{{now | date('d.m.Y') }}</caption>
	<thead>
	<tr class="thead2"><th>ФИО</th><th>Должность</th><th>Статус</th><th>Кол-во часов</th></tr>
	</thead>
	<tbody>
	{% for p in pers %}
		<tr class="perstr" id="{{ p.persID }}"><td> {{ p.fam }} {{ p.im }} {{ p.ot }}</td>
			<td>{{ p.workname }}</td>	
			<td><select name="statusID" class="statuses"><option value="-1" selected>...</option>
				{% for s in statuses %}<option value="{{ s.id }}">{{ s.statusname }}</option>{% endfor %}</select></td>
			<td><select name="hours" class="hours">
				{% for h in hours %}<option value="{{ h }}">{{ h }}</option>{% endfor %}<option value="0" selected>0</option>
			</select></td>
			<input type="hidden" name="daynow" class="daynow" value="{{ now | date('Y-m-d') }}"></input>
		</tr>
	{% endfor %}
	</tbody>
</table>
<button type="submit">Отправить</button>
</form>

Отправляется форма с помощью jquery
			$("#tableform").on("submit", function(e){
				e.preventDefault();
				let reqq = [];
				workers.each(function() {
					let persID = $(this).attr('id');//.text();
					let simple = {};
					let hours = 0;
					let ho = '';
					simple.persID = persID;
					simple.daynow = $(this).find('.daynow').val();
					simple.statusID = $(this).find('.statuses').val();
					
					// если по кому-то не заполнено, то не отправляем
					if (simple.statusID >0) { 
						ho = $(this).find('.hours').val();
						hours = (Number(ho)).toFixed(1);
						simple.hours = hours;
						reqq.push(simple);
					}
				});
				
				$.ajax({
					url: "/office/save",
					method: 'post',
					data: { reqq },
					success: function(data){
						// если информация занесена в базу, то не показываем сегодня больше форму а переадресуем на страницу месяца
						location.assign("/office/showMonth/"+m);
					}
				});
			});

 Обработка формы на сервере:
 
		if ($request->request){
			$cont = $request->get('reqq');
				$p1 = 'ok!';
			foreach ($cont as $key => $value) {
				$dayList = new Day();
				$i++;
				$targetDay = date_create_from_format('Y-m-d',$value['daynow']); 
				$dayList->setDaynow($targetDay);
				$dayList->setPers($doctrine->getRepository(Pers::class)->find($value['persID']));
				$dayList->setStatuses($doctrine->getRepository(Status::class)->find($value['statusID']));
				$dayList->setHours($value['hours']);
				$entityManager->persist($dayList);
				$entityManager->flush();
				$entityManager->clear();
			}
		}
  
2. Сложные запросы с помощью Doctrine

	public function findAllOffice(): array
    {
        $entityManager = $this->getEntityManager();
        $query = $entityManager->createQuery(
            'SELECT p.id as persID, p.fam, p.im, p.ot, w.workname, w.trevelpayment, w.id as workID
            FROM App\Entity\Pers p
			      JOIN p.work w 
			      WHERE w.department = :dep
			      AND p.isWork = :is
            ORDER BY p.fam ASC'
        ) 
		    ->setParameter('dep', 3)
		    ->setParameter('is', 1); 
		
        // возвращает массив объектов 
        return $query->getResult();
    }
 
    public function findByID($id): ?array//Pers
    {
        $entityManager = $this->getEntityManager();
        $query = $entityManager->createQuery(
            'SELECT d.id as did, d.daynow, d.hours, p.id as pid, p.fam, p.im, p.ot, w.workname, w.cost, s.id as sid, s.statusname
            FROM App\Entity\Day d
			      JOIN d.pers p
			      JOIN p.work w
			      JOIN d.status s
			      WHERE d.id = :id ')
        ->setParameter('id', $id);
		    return $query->getResult();
    }
	
3. Вывод данных о сотрудниках за месяц
    
	 #[Route('/office/showMonth/{monthN}', name: 'app_showMonth')]	
	public function showMonth($monthN, ManagerRegistry $doctrine): Response	
    {
		$persDays = array();
    $persList = $doctrine->getRepository(Pers::class)->findAllPersonal();
		$dayList = [];	
		$countDays = cal_days_in_month(CAL_GREGORIAN, $this->currentM, $this->currentY); // количество дней в месяце
		$today = $this->currentY."-".$monthN;
		$statuses = $doctrine->getRepository(Status::class)->findAll();
		
		for ($d=1; $d < ($countDays+1); $d++) {
			if ($d<10)	$dayList[$d-1] = $today."-0".$d;
			else	$dayList[$d-1] = $today."-".$d;
			if ( $dayList[$d-1] == $this->now ) break;
		}
		$i = 0;
		$resp = '';
		$p = '';
		foreach ($persList as $key => $value) {
			$data = array();
			$p = $value['persID'];
			$fio = $value['fam'].' '.$value['im'].' '.$value['ot'];		 
			foreach ($dayList as $keyD => $valueD) {
       // берём из базы данные по этому человку и дню
				$dd = $doctrine->getRepository(Day::class)->findIndividualDay($valueD,$p);
				$exp = [];
				$data[$valueD] = array('daynow' => $valueD,'find' => $dd);
			}
			$persDays[$key] = array('persID' => $p, 'fio' => $fio, 'work' => $value['workname'], 'data' => $data);
		}
        return $this->render('office/month.html.twig', [
			'pers' => $persList, 
			'day' => $dayList, 
			'today' => $today,
			'now' => $this->now,
			'year' => $this->currentY,
			'statuses' => $statuses, 
			'persDays' => $persDays,
			'hours' => $this->hours,
        ]);
